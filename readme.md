# GenAI_HostedInternal — Local LLM Gateway Evaluation (Delphi)

A small Delphi console project to **test connectivity, authentication, and basic requests** against a **locally hosted / internal LLM gateway** that exposes **OpenAI-compatible endpoints** (e.g., `/chat/completions`, `/models`, `/embeddings`) [2].

---

## Purpose

- Evaluate access to **locally hosted AI models** via a gateway (“LLM gateway console test”) [1]
- Validate:
  - Base URL + endpoint paths (chat, models, embeddings) [2]
  - Authentication/token retrieval (`/auth/token`) [1] [2]
  - Client configuration: model name, max tokens, timeouts, temperature [1] [2]

---

## Project structure

### Entry point (console app)
- **`GenAI_HostedInternal.dpr`**
  - Prints key runtime settings:
    - Parameter file name
    - “OpenAI base” URL composed from `HostURL + CHAT_COMPLETIONS`
    - Token endpoint URL `HostURL + AUTH_TOKEN_ENDPOINT`
    - Selected model and max tokens [1]
  - Includes the key units for communication, token retrieval, and helpers [1]
  - Supports retrieving a token via:
    - **Basic auth** (username/password) using `GetPermanentTokenViaBasic(...)`
    - **Token endpoint** using `GetCompanyInternalToken` [1]

### Configuration
- **`Config_AIModels.ini`**
  - Defines the gateway and endpoint paths [2]:
    - `BaseURL`
    - `ChatCompletions`, `Completions`, `Embeddings`, `ImagesGenerations`, `Models`
    - `AuthTokenEndpoint`
  - Auth section supports `Method=Basic` or `Method=Bearer`, plus optional `Token` [2]
  - TLS section: `CABundle`, `VerifyPeer` [2]
  - Client defaults: `Model`, `TimeoutMS`, `Temperature`, `MaxTokens`, `Stream` [2]

### Core units
- **`Unit_AIModel.TAIModelConfig.pas`**
  - Reads config values like `ModelsPath` and `AuthTokenEndpoint` from INI [3]
  - Creates HTTP client (`TIdHTTP`) with JSON headers/timeouts [3]
  - Notes TLS verification is “basic” and suggests production improvements (peer verification / CA handling) [3]

- **`Unit_AIModel.GetInternalToken.pas`**
  - Implements `GetCompanyInternalToken(...)`
  - Default overload calls the parameterized version with timeout and `'/auth/token'` [7]

- **`Unit_AIModel.Probing.pas`**
  - Builds an Authorization header; can auto-fetch token via `GetCompanyInternalToken` [6]
  - Probes `/models` via `GET BaseURL + ModelsPath` and expects HTTP 200 [6]

- **`Unit_AIModel.Embeddings.pas`**
  - Builds an embeddings request using `Config.BaseURL + Config.EmbeddingsPath` [5]
  - Sends OpenAI-style JSON with `model`, `input`, and `encoding_format=float` [5]
  - Contains a simple cache with HIT/MISS messages when debug is enabled [5]

- **`Unit_AIModel.Communication.pas`**
  - Provides Basic auth header encoding and request debugging helpers [9]
  - Defines `AUTH_TOKEN_ENDPOINT = '/auth/token'` [9]

- **`Unit_AIModel.Helper.pas`**
  - Contains utilities such as `JoinUrl(...)` and model-family helpers [8]

---

## How to use

### 1) Configure your gateway URL and endpoints
Edit `Config_AIModels.ini`:

```ini
[server]
BaseURL=https://your-gateway.example
ChatCompletions=/chat/completions
Models=/models
Embeddings=/embeddings
AuthTokenEndpoint=/auth/token
