type Assert<T extends true> = T;
type IsAny<T> = 0 extends (1 & T) ? true : false;
function twice(value: number): number { return value * 2; }
const result = twice(21);
type ResultIsNumber = Assert<typeof result extends number ? true : false>;
type ResultIsNotAny = Assert<IsAny<typeof result> extends false ? true : false>;
type FunctionIsNotAny = Assert<IsAny<typeof twice> extends false ? true : false>;
export {};
