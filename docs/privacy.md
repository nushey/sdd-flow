---
title: Privacy policy
---

# Privacy policy

sdd-flow is maintained by Nahuel Zeballos. This policy describes the bundled
workflows, checker, and installer in the
[public repository](https://github.com/nushey/sdd-flow).

## Project data and execution

The skills and agent instructions run through your selected coding host. They
direct it to read project instructions, source files, requirements, plans, diffs,
Git history, and test output as needed for the requested work. They can write
code, documents, and `.spec/` artifacts, run tools and tests, and create local
commits according to the workflow and the host's permissions.

The bundled Python contract checker reads local specification files and invokes
local Git commands. It contains no network client or telemetry. It uses Python's
standard library and Git, with no third-party Python packages.

## Third parties and the host platform

sdd-flow provides no developer-operated endpoint for receiving project files
and includes no analytics or project-data upload service. The host platform
may transmit prompts, file contents, tool output, and agent conversations to
its provider. Optional project tools, MCP connections, test commands, or
dependencies may communicate with their own services. Their processing,
permissions, and retention are governed by those providers and your settings.
Running a workflow locally does not mean the host's model processing is local.

Downloading or updating sdd-flow contacts GitHub through the installer or
download command. Visiting documentation also contacts its hosting provider.
Those providers may process connection information under their own policies.

## Information received by the maintainer and retention

Normal workflow execution does not send project data to the maintainer through
bundled sdd-flow code. If you submit a GitHub issue or contact the maintainer,
the maintainer can receive the information you choose to share. Do not include
credentials or private project content in public issues.

Project files, `.spec/` artifacts, installation caches, and Git commits persist
in your environment until you remove them; removing a working file does not
erase its Git history. Host conversation records and GitHub submissions have
their own retention policies. sdd-flow does not enforce a separate retention
schedule or automatically delete these records.

For questions, use [GitHub Issues](https://github.com/nushey/sdd-flow/issues). For sensitive inquiries, contact
the maintainer at zeballosnahuelfd@gmail.com rather than posting publicly.
