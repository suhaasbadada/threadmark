import Combine
import Foundation

/// Host-owned current binding. Update on EVERY draft/query/project/policy/profile/
/// configuration change, even if it changes back. IDs here are not credentials.
public struct RetainedReviewBinding: Equatable, Sendable {
    public let consentID: UUID
    public let project: Project
    public let original: String
    public let query: String
    public let settings: ProviderSettings
    public let generation: UInt64
    public let scopeRevision: UInt64
    public let configurationGeneration: UInt64

    public init(consentID: UUID, project: Project, original: String, query: String,
                settings: ProviderSettings, generation: UInt64, scopeRevision: UInt64,
                configurationGeneration: UInt64) {
        self.consentID = consentID; self.project = project; self.original = original; self.query = query
        self.settings = settings; self.generation = generation; self.scopeRevision = scopeRevision
        self.configurationGeneration = configurationGeneration
    }
    public init(consent: RefinementConsent, configurationGeneration: UInt64) {
        self.init(consentID: consent.id, project: consent.project, original: consent.original, query: consent.query,
                  settings: consent.settings, generation: consent.generation, scopeRevision: consent.scopeRevision,
                  configurationGeneration: configurationGeneration)
    }
    func matches(_ consent: RefinementConsent) -> Bool {
        self == Self(consent: consent, configurationGeneration: configurationGeneration) &&
        original.utf8.elementsEqual(consent.original.utf8) && query.utf8.elementsEqual(consent.query.utf8)
    }
}

public enum RetainedReviewState: Equatable, Sendable {
    case idle, preparing, needsInput, ready, reviewRequired, failed, canceled
    case approvedValue(RetainedReviewHandoff)
}

/// Retain in the model's owned-operation registry while review is idle too.
/// Cancellation is synchronous; acknowledgment is the awaited worker join.
public struct RetainedReviewLifetime: Sendable {
    private let process: RetainedReviewProcess
    init(_ process: RetainedReviewProcess) { self.process = process }
    public func cancel() { process.cancel() }
    public func join() async { _ = await process.join() }
}

/// Protocol-specific controller, deliberately not mounted in the app by this lane.
/// Each method is ONE human action; never retries, falls back or starts inference
/// after an edit. Approval produces only an actual Rust value, not host admission.
@MainActor public final class RetainedReviewController: ObservableObject {
    @Published public private(set) var state: RetainedReviewState = .idle
    @Published public private(set) var original = ""
    @Published public private(set) var proposed: String?
    @Published public private(set) var questions: [String] = []
    @Published public private(set) var editable: RetainedReviewEditable?
    @Published public private(set) var challenge: RetainedReviewChallenge?
    @Published public private(set) var lastError: ServiceError?
    @Published public private(set) var busy = false
    public private(set) var consent: RefinementConsent?
    public private(set) var binding: RetainedReviewBinding?
    private var process: RetainedReviewProcess?
    private var generation: UInt64 = 0
    private var usedConsentIDs = Set<UUID>()
    private var pendingChoice: String?
    private var monitoring: Task<Void, Never>?
    var ownedPID: Int32? { process?.pid }
    public var ownedLifetime: RetainedReviewLifetime? { process.map(RetainedReviewLifetime.init) }

    public init() {}
    deinit { process?.cancel(); monitoring?.cancel() }

    /// Call and await BEFORE rebinding the common model. The returned completion
    /// is the quit/operation-registry join boundary, not merely cancel requested.
    public func synchronize(_ current: RetainedReviewBinding?) async {
        generation &+= 1
        let ticket = generation
        let previous = process
        monitoring?.cancel(); monitoring = nil
        busy = true
        await previous?.cancelAndJoin()
        guard generation == ticket else { return }
        process = nil; binding = current; consent = nil; original = ""; proposed = nil; questions = []
        editable = nil; challenge = nil; lastError = nil; pendingChoice = nil
        state = .idle; busy = false
    }

    public func cancelAndJoin() async {
        generation &+= 1
        let ticket = generation
        let previous = process
        monitoring?.cancel(); monitoring = nil
        busy = true
        await previous?.cancelAndJoin()
        guard generation == ticket else { return }
        process = nil; state = .canceled; proposed = nil; editable = nil; questions = []; challenge = nil
        pendingChoice = nil; busy = false
    }

    /// Requires an existing immutable confirmation and an explicitly synchronized
    /// current binding. Reusing a consumed consent cannot silently start a session.
    public func start(consent: RefinementConsent, executable: URL, store: URL) async {
        await start(consent: consent, executable: executable, store: store, seconds: 300)
    }
    // Internal shorter parent deadline for bounded tests, never a CLI override.
    func start(consent: RefinementConsent, executable: URL, store: URL, seconds: Double,
               didSpawn: (@Sendable (Int32) -> Void)? = nil) async {
        guard !busy, process == nil, binding?.matches(consent) == true,
              !usedConsentIDs.contains(consent.id) else { lastError = .invalid; return }
        do {
            try consent.validate()
            let child = try RetainedReviewProcess(executable: executable, store: store, consent: consent, seconds: seconds, didSpawn: didSpawn)
            usedConsentIDs.insert(consent.id)
            self.consent = consent; original = consent.original; process = child
            state = .preparing; lastError = nil
            await perform(.capture(consent.original), child: child)
            guard process === child else { return }
            let ticket = generation
            monitoring = Task { [weak self] in
                let failure = await child.join()
                guard !Task.isCancelled, let self, self.generation == ticket, self.process === child else { return }
                if let failure {
                    self.process = nil; self.state = failure == .canceled ? .canceled : .failed; self.lastError = failure
                    self.challenge = nil; self.editable = nil; self.proposed = nil
                    self.pendingChoice = nil; self.busy = false
                }
            }
        } catch {
            state = .failed; lastError = error as? ServiceError ?? .invalid
        }
    }

    public func edit(_ challenge: RetainedReviewChallenge, objective: String, outputExpectations: String) async {
        guard !busy, let child = process, editable != nil else { return }
        guard challenge == self.challenge else { state = .reviewRequired; return }
        await perform(.edit(challenge, objective, outputExpectations), child: child)
    }
    public func usePrepared(_ challenge: RetainedReviewChallenge) async {
        guard !busy, let child = process else { return }
        guard challenge == self.challenge, proposed != nil, questions.isEmpty,
              state == .ready || state == .reviewRequired else { state = .reviewRequired; return }
        // A needsinput preview with empty questions (no evidence) is not ready.
        guard consent?.selection.results.isEmpty == false else { state = .reviewRequired; return }
        pendingChoice = "use-prepared"
        await perform(.prepared(challenge), child: child)
    }
    public func useOriginal(_ challenge: RetainedReviewChallenge) async {
        guard !busy, let child = process else { return }
        guard challenge == self.challenge else { state = .reviewRequired; return }
        pendingChoice = "use-original"
        await perform(.original(challenge), child: child)
    }

    private func perform(_ command: RetainedReviewCommand, child: RetainedReviewProcess) async {
        let ticket = generation
        busy = true
        do {
            let event = try await child.exchange(command)
            if event.terminal { _ = await child.join() }
            guard !Task.isCancelled else { throw ServiceError.canceled }
            guard generation == ticket, process === child, let consent,
                  binding?.matches(consent) == true else { return }
            switch event.event {
            case "preview", "needsinput":
                guard let next = event.challenge,
                      next.revision == (challenge?.revision ?? 0) + 1,
                      challenge?.digest != next.digest else { throw ServiceError.invalid }
                challenge = next; proposed = event.proposed; editable = event.editable
                questions = event.material_questions ?? []
                state = event.event == "preview" ? .ready : .needsInput
            case "failure":
                if event.code == "ReviewRequired" {
                    guard challenge != nil else { throw ServiceError.invalid }
                    state = .reviewRequired
                } else {
                    if !event.terminal {
                        guard challenge == nil, event.challenge?.revision == 1 else { throw ServiceError.invalid }
                        challenge = event.challenge
                    } else { challenge = nil }
                    state = .failed; proposed = nil; editable = nil; lastError = .failed
                }
            case "canceled": state = .canceled; challenge = nil
            case "handoff":
                guard event.challenge == challenge, event.choice == pendingChoice, let text = event.text,
                      let expected = event.choice == "use-original" ? consent.original : proposed,
                      text.utf8.elementsEqual(expected.utf8) else { throw ServiceError.invalid }
                state = .approvedValue(.init(text: text, choice: event.choice!))
                challenge = nil
            default: throw ServiceError.invalid
            }
            if event.terminal { process = nil; monitoring?.cancel(); monitoring = nil }
            pendingChoice = nil; busy = false
        } catch {
            await child.cancelAndJoin()
            guard generation == ticket, process === child else { return }
            process = nil; state = Task.isCancelled ? .canceled : .failed
            lastError = error as? ServiceError ?? .invalid; challenge = nil; editable = nil
            proposed = nil; questions = []
            pendingChoice = nil; busy = false
        }
    }
}
