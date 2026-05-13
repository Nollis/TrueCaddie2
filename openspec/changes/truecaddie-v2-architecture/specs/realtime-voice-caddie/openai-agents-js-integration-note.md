# OpenAI Agents JS Integration Note

> Superseded as the preferred architecture on 2026-05-13.
> TrueCaddie is now targeting a Swift-first native realtime voice path for the pilot iOS app, with no separate TrueCaddie server by default.
> Keep this note as reference scaffolding only for parity checks, fallback exploration, or future cross-platform work.

This note shows the intended integration path between a future JS voice client using OpenAI Agents SDK voice agents and the Swift bridge that already exists in this repo.

The goal is to keep golf logic grounded in the Swift-side caddie bridge while letting a `RealtimeAgent` / `RealtimeSession` act as the low-latency voice layer.

## Why this shape

The current Swift bridge already exports the pieces a voice runtime needs:

- `openAIFunctionTools()` for function-tool definitions
- `wireRequest(from:)` and `wireRequest(toolName:argumentsJSON:)` for incoming tool calls
- `VoiceSessionBridge.respond(...)` for grounded response generation
- `RealtimeAgentStub.resolveToolCall(...)` as the local adapter seam

This lines up with the OpenAI Agents SDK guidance:

- `RealtimeAgent` and `RealtimeSession` are the main voice-session primitives.
- Realtime voice agents support function tools.
- Function tools run where the `RealtimeSession` runs, so protected logic should use a backchannel/server-side pattern when needed.

Sources:

- [Voice Agents Quickstart](https://openai.github.io/openai-agents-js/guides/voice-agents/quickstart/)
- [Building Voice Agents](https://openai.github.io/openai-agents-js/guides/voice-agents/build/)

## Repo bridge surface

Current Swift entry points live in:

- [ContentView.swift](C:/Users/niklasb/Documents/New%20project%202/ios/TrueCaddieHost/TrueCaddieHost/ContentView.swift)

Key exported shapes:

- `HostCaddieSession.VoiceSessionBridge.openAIFunctionTools()`
- `HostCaddieSession.VoiceSessionBridge.wireRequest(from:)`
- `HostCaddieSession.VoiceSessionBridge.wireRequest(toolName:argumentsJSON:)`
- `HostCaddieSession.VoiceSessionBridge.respond(to:context:)`
- `HostCaddieSession.RealtimeAgentStub.configuration()`
- `HostCaddieSession.RealtimeAgentStub.resolveToolCall(name:argumentsJSON:context:)`

## Recommended integration shape

Use a thin JS voice layer and keep strategy + round updates behind a server/backchannel boundary:

1. The JS layer starts a `RealtimeSession`.
2. The JS layer builds function tools from the exported TrueCaddie tool catalog.
3. Each tool call forwards `name + arguments` to a backend endpoint.
4. The backend reconstructs `TurnContext` from the current round/session state.
5. The backend calls the Swift bridge and returns the grounded result.
6. The JS tool returns that result to the realtime session.

That keeps:

- voice timing in the JS/OpenAI runtime
- golf truth in the Swift bridge
- protected business logic out of the browser tool implementation

## Sample JS shape

This is an integration sketch, not a production-ready file. It shows the intended flow and should be adapted to the exact project structure.

```ts
import { RealtimeAgent, RealtimeSession, tool } from '@openai/agents/realtime';
import { z } from 'zod';

type WireToolParameterDefinition = {
  name: string;
  type: string;
  required: boolean;
  description: string;
  allowedValues?: string[] | null;
};

type WireToolCatalogEntry = {
  name: string;
  description: string;
  parameters: WireToolParameterDefinition[];
  sampleUtterances: string[];
};

type WireSessionResponse = {
  actionName: string;
  assistantReply: string;
  state: {
    selectedHoleNumber: number;
    roundContext: {
      teeSetId: string;
      teeSetName: string;
      strategyPreference: string;
      windRelativeDirection?: string | null;
      windSpeedMps?: number | null;
    };
    roundState: unknown;
    availableToolNames: string[];
  };
  strategyPreference?: string | null;
};

function zodSchemaForTool(toolDef: WireToolCatalogEntry) {
  const shape: Record<string, z.ZodTypeAny> = {};

  for (const param of toolDef.parameters) {
    let field: z.ZodTypeAny;

    if (param.allowedValues && param.allowedValues.length > 0) {
      field = z.enum(param.allowedValues as [string, ...string[]]);
    } else if (param.type === 'number' || param.type === 'Double') {
      field = z.number();
    } else if (param.type === 'integer' || param.type === 'Int') {
      field = z.number().int();
    } else {
      field = z.string();
    }

    shape[param.name] = param.required ? field : field.optional();
  }

  return z.object(shape);
}

async function loadTrueCaddieTools() {
  const response = await fetch('/api/truecaddie/voice/tools');
  const toolDefs: WireToolCatalogEntry[] = await response.json();

  return toolDefs.map((toolDef) =>
    tool({
      name: toolDef.name,
      description: toolDef.description,
      parameters: zodSchemaForTool(toolDef),
      execute: async (args) => {
        const result = await fetch('/api/truecaddie/voice/tool-call', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name: toolDef.name,
            arguments: args,
          }),
        });

        const grounded: WireSessionResponse = await result.json();

        // Keep this short because the realtime session will speak it.
        return grounded.assistantReply;
      },
    })
  );
}

export async function createTrueCaddieSession(clientSecret: string) {
  const tools = await loadTrueCaddieTools();

  const agent = new RealtimeAgent({
    name: 'TrueCaddie',
    instructions:
      'You are a calm, concise golf caddie. Use tools for grounded recommendations and round-state updates. Do not invent strategy.',
    tools,
  });

  const session = new RealtimeSession(agent, {
    model: 'gpt-realtime-2',
  });

  await session.connect({ apiKey: clientSecret });
  return session;
}
```

## Sample backend shape

The backend endpoint is the place that should own round/session state and call the Swift bridge.

```ts
// POST /api/truecaddie/voice/tool-call
export async function POST(req: Request) {
  const body = await req.json();

  // The backend should resolve the active round context from session state,
  // not trust the browser to be the source of golf truth.
  const bridgeResponse = await callSwiftBridge({
    toolName: body.name,
    arguments: JSON.stringify(body.arguments),
  });

  return Response.json(bridgeResponse);
}
```

## Mapping to the Swift bridge

The intended bridge calls are:

1. Tool catalog endpoint
   - Swift source: `HostCaddieSession.VoiceSessionBridge.openAIFunctionTools()`
   - Browser purpose: build `tool(...)` definitions

2. Tool call endpoint
   - Swift source: `HostCaddieSession.RealtimeAgentStub.resolveToolCall(name:argumentsJSON:context:)`
   - Browser purpose: send tool `name + arguments`

3. Session response
   - Swift source: `WireSessionResponse`
   - Browser purpose: return grounded spoken output plus updated session state

## Important constraint

Do not move recommendation logic into the JS tool handlers.

The JS/OpenAI layer should only:

- expose the tools
- forward tool calls
- return grounded results

The Swift bridge should remain the place where:

- round state mutates
- strategy is resolved
- voice-facing reply text is grounded
