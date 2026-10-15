// SPDX-License-Identifier: Apache-2.0
import JSONFilterRuntime

/// Help describes this compiled dialect, rather than a proposed compatibility set.
package enum CLIHelp {
    package static var versionJSON: String {
        #if os(macOS)
        let platform = "macOS"
        #elseif os(Linux)
        let platform = "Linux-glibc"
        #else
        let platform = "unqualified"
        #endif
        #if arch(arm64)
        let architecture = "arm64"
        #elseif arch(x86_64)
        let architecture = "x86_64"
        #elseif arch(wasm32)
        let architecture = "wasm32"
        #else
        let architecture = "unknown"
        #endif
        return "{\"version\":\"1.4.0-dev\",\"revision\":\"unknown\",\"platform\":\"\(platform)\",\"architecture\":\"\(architecture)\",\"features\":[\"format\",\"validate\",\"pointer\",\"patch\",\"query\",\"stream\",\"schema-check\",\"openai-format\",\"openai-tool\",\"render-html\",\"render-markdown\",\"render-text\"],\"dialect\":\"swift-json-filter/1\"}\n"
    }
    package static func text(for command: String?) throws -> String {
        let common = """
        INPUT defaults to stdin (-). JSON is strict UTF-8; duplicate decoded keys fail.
        --limits conservative|balanced|offline    finite resource profile
        --limits-file PATH                       version 1 finite overrides
        --output PATH [--overwrite]              atomic installation after EOF
        --diagnostics human|json --report none|json   stderr only
        -- terminates option recognition, including leading-dash file names.
        No online references, environment data, shell execution or remote providers.

        """
        let body: String
        switch command {
        case nil:
            body = """
            Usage: swift-json COMMAND [OPTIONS] [INPUT]

            format       Format one strict JSON document.
            validate     Validate strict JSON with an optional offline schema.
            pointer      Select an RFC 6901 Pointer; null differs from absence.
            patch        Apply a staged RFC 6902 patch from --patch PATH.
            query FILTER Pull exact filter results with complete input validation.
            stream       Check, copy records, or pull root-array elements.
            schema check Compile an explicit offline Draft 2020-12 schema.
            render       Produce static/interactive HTML, text or Markdown.
            help COMMAND Show command options. --version [--json] shows this build.

            """
        case "format": body = """
            Usage: swift-json format [INPUT] [OPTIONS]
            --compact | --indent 0...8 | --tab  (default two spaces)
            --sort-keys --number-style preserved|normalized (default preserved)
            Emits one complete document followed by LF.

            """
        case "validate": body = """
            Usage: swift-json validate [INPUT] [--schema PATH] [OPTIONS]
            --resource URI=PATH (repeatable) --max-issues N
            Emits {valid,issues,truncated}. Invalid instance exits 1;
            malformed input, invalid schema or missing offline resource exits 5.

            """
        case "pointer": body = """
            Usage: swift-json pointer POINTER [INPUT] [--allow-missing]
            RFC 6901 selection emits explicit null. Missing with --allow-missing
            emits no value and exits 4; malformed Pointer/index remains an error.

            """
        case "patch": body = """
            Usage: swift-json patch [INPUT] --patch PATH
            Staged RFC 6902 operations emit only a successful candidate.
            Root removal emits no JSON value; it differs from JSON null.

            """
        case "stream": body = """
            Usage: swift-json stream check|cat|array [INPUT...] [OPTIONS]
            check/cat: --framing document|values|ndjson (default values)
            check emits {completed,inputRecords} after all EOF boundaries.
            cat/array emit compact JSON+LF per admitted record/element.
            array requires a root array; its closing syntax and EOF certify success.
            Stdout may contain an accepted prefix on a later failure.

            """
        case "schema": body = """
            Usage: swift-json schema check SCHEMA [--resource URI=PATH] [OPTIONS]
            Compiles one offline Draft 2020-12 object/Boolean schema and emits
            completed metadata. This command does not validate an instance or fetch.
            schema provider openai-format|openai-tool SCHEMA --name NAME
            Optional --description TEXT and explicit --resource URI=PATH.
            Frozen strict Responses base-model profiles preserve declarations unchanged.
            Success emits a native text.format fragment or flat function tool. Incompatible
            or unverified schemas emit bounded compatibility issues and exit 1.
            These local helpers make no API requests and do not guarantee service acceptance.

            """
        case "render": body = """
            Usage: swift-json render [INPUT] [OPTIONS]
            --format html|markdown|text (default html)
            HTML: --presentation static|interactive (default static)
            --theme system|light|dark --title TEXT
            --html PATH is shorthand for HTML --output PATH.
            Static HTML is expanded and script-free. Text/Markdown use real tabs;
            Markdown wraps exact JSON in a JSON code fence.

            """
        case "query": body = """
            Usage: swift-json query FILTER [INPUT...] [OPTIONS]
            -f/--filter-file PATH replaces FILTER. Default framing is values;
            --input-framing document|values|ndjson selects strict JSON framing.
            -n/--null-input, -s/--slurp, -R/--raw-input select bounded input modes.
            -n conflicts with -s; -R conflicts with explicit JSON framing.
            --arg NAME TEXT --argjson NAME JSON --rawfile NAME PATH
            --slurpfile NAME PATH; --args/--jsonargs capture remaining argv.
            -c/--compact-output | --indent 0...8 | --tab; -S/--sort-keys
            --number-style preserved|normalized; -a/--ascii-output
            -r/--raw-output | --raw-output0 | -j/--join-output
            -e/--exit-status uses the final semantic result only after complete EOF.
            --unbuffered awaits each complete record. Raw and ASCII modes conflict.
            Exact +,-,*,/,integral %, reductions, functions, paths, assignment,
            collections, scalar strings and format encoders share finite budgets.
            Repeating division fails unless --division-scale N --rounding half-even
            is explicit. No floating approximation, regex, modules or environment.
            first/short-circuit stops its generator; the job still checks input tails.

            """
        default: throw CLIError(.usage, "unknownHelpCommand")
        }
        return body + common
    }
}
