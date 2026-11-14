import type { OpenCodeClient } from "@opencode/client";
import type { Plugin as ServerPlugin } from "@opencode/plugin";
import type { Plugin as TuiPlugin } from "@opencode/plugin/tui";
import type { rgbToOklch } from "@opencode/theme/tui";
import type { RGBA } from "@opentui/core";
import type { render, JSX } from "@opentui/solid";
import type { Accessor } from "solid-js";
import type { Parser, Point } from "web-tree-sitter";
import type { JSONSchema7Definition } from "json-schema";

type Concrete<T> = 0 extends (1 & T) ? false : true;

export function positive(
  client: OpenCodeClient,
  server: typeof ServerPlugin,
  tui: typeof TuiPlugin,
  color: typeof rgbToOklch,
  rgba: typeof RGBA,
  renderer: typeof render,
  parser: typeof Parser,
  accessor: Accessor<string>,
): void {
  const session: OpenCodeClient["session"] = client.session;
  const sessionConcrete: Concrete<typeof session> = true;
  const serverPlugin = server.define({ id: "synthetic-sdk", setup(context) {
    const name: string = context.app.name;
    const concrete: Concrete<typeof context.app.name> = true;
    void name; void concrete;
  } });
  const tuiPlugin = tui.define({ id: "synthetic-sdk", setup(context) {
    const cost: number = context.data.session.cost("synthetic-session");
    const concrete: Concrete<ReturnType<typeof context.data.session.cost>> = true;
    void cost; void concrete;
  } });
  const lightness: number = color(12, 34, 56).l;
  const colorConcrete: Concrete<ReturnType<typeof color>> = true;
  const pixel: RGBA = rgba.fromInts(12, 34, 56);
  const pixelConcrete: Concrete<ReturnType<typeof rgba.fromInts>> = true;
  const view: JSX.Element = <box id="synthetic-box"><text>synthetic</text></box>;
  const jsxConcrete: Concrete<JSX.Element> = true;
  const rendererConcrete: Concrete<typeof renderer> = true;
  const text: string = accessor();
  const solidConcrete: Concrete<ReturnType<typeof accessor>> = true;
  const point: Point = { row: 0, column: 0 };
  const initialize: (options?: EmscriptenModule) => Promise<void> = parser.init;
  const parserConcrete: Concrete<typeof parser.init> = true;
  const schema: JSONSchema7Definition = { type: "string" };
  void sessionConcrete; void serverPlugin; void tuiPlugin; void lightness;
  void colorConcrete; void pixel; void pixelConcrete; void view; void jsxConcrete;
  void rendererConcrete; void text; void solidConcrete; void point;
  void initialize; void parserConcrete; void schema;
}
