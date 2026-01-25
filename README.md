<div align="center">
  <h1 align="center">🎮 RMatchmakerC 🎮</h1>
  <p align="center">
    A lightweight, minimal matchmaker for Roblox with a C++ backend server.
    <br />
    <a href="https://github.com/rain-lua/RMatchmakerC/issues">Report Bug</a>
    ·
    <a href="https://github.com/rain-lua/RMatchmakerC/issues">Request Feature</a>
  </p>
</div>

> ⚠️ **Status:** Work in progress — This is an educational and base implementation only. It is not recommended for production use without further development.

---

## 🚀 Overview

RMatchmakerC provides a **high-performance matchmaking system** for Roblox games. It pairs players efficiently and manages queues using a **C++ backend** with **HTTP communication**.

> ⚠️ **Note:** This is a **learning/prototyping project**. It is not production-ready. Please add security, error handling, persistence, and scaling before deploying.

---

## ✨ Features

- 🏎 **High-performance C++ backend:** Built for speed and efficiency.
- 🔐 **Secure communication:** Uses HMAC-SHA256 to verify requests.
- 📡 **HTTP-based communication:** Simple and easy to integrate with Roblox.
- 🛠 **Lua integration:** Seamlessly connect with your Roblox game.
- 📝 **JSON support:** For easy data serialization.
- 🎯 **Minimal and lightweight design:** No unnecessary bloat.

---

## 📂 Project Structure

```
RMatchmakerC/
├── backend/                  # C++ backend server
│   ├── include/              # Header libraries (httplib, nlohmann/json)
│   └── main.cpp
├── src/                      # Roblox Lua source files
│   ├── ServerScriptService/
│   └── ServerStorage/
│       └── MatchmakingClient/
│           ├── init.lua
│           ├── Config.lua
│           └── HMAC_SHA256.lua
├── server                    # Compiled C++ backend
└── README.md
```

---

## 🔐 Security

All communication between the Roblox game and the C++ backend is secured using **HMAC-SHA256**.

- A **shared secret key** is used to sign and verify requests.
- **Timestamps** are included in the signature to prevent replay attacks.
- The `X-Timestamp` and `X-Signature` headers are required for all requests.

> **Important:** The secret key in the source code is for demonstration purposes only. **You must change it** before using this project.

---

## 🛠 Getting Started

Follow these steps to set up the backend and connect it to your Roblox game.

### 1️⃣ **Clone the repository**

```bash
git clone https://github.com/rain-lua/RMatchmakerC.git
cd RMatchmakerC
```

### 2️⃣ **Build the C++ backend**

The backend requires a C++ compiler, `httplib`, `nlohmann/json`, and OpenSSL.

#### **Windows**

1. **Install a C++ compiler:**
   - Install Visual Studio with the "Desktop development with C++" workload.
   - Alternatively, install `g++` via [MinGW-w64](https://www.mingw-w64.org/).

2. **Install OpenSSL:**
   - Download a pre-compiled binary from [Shining Light Productions](https://slproweb.com/products/Win32OpenSSL.html).
   - During installation, choose to copy the DLLs to the Windows system directory.

3. **Build the server:**
   - Open a terminal or command prompt.
   - Replace `"path/to/openssl"` with the actual installation path.

   ```bash
   g++ backend/main.cpp -o server.exe -std=c++17 -I "path/to/openssl/include" -L "path/to/openssl/lib" -lws2_32 -lbcrypt -lcrypto -lssl
   ```

#### **macOS**

1. **Install Xcode Command Line Tools:**
   ```bash
   xcode-select --install
   ```

2. **Install OpenSSL:**
   ```bash
   brew install openssl
   ```

3. **Build the server:**
   ```bash
   g++ backend/main.cpp -o server -std=c++17 -I/usr/local/opt/openssl/include -L/usr/local/opt/openssl/lib -lssl -lcrypto -pthread -luuid
   ```

#### **Linux (Debian/Ubuntu)**

1. **Install build tools and OpenSSL:**
   ```bash
   sudo apt-get update
   sudo apt-get install build-essential libssl-dev uuid-dev
   ```

2. **Build the server:**
   ```bash
   g++ backend/main.cpp -o server -std=c++17 -lssl -lcrypto -pthread -luuid
   ```

#### **Linux (Arch)**

1. **Install build tools and OpenSSL:**
   ```bash
   sudo pacman -S base-devel openssl util-linux
   ```

2. **Build the server:**
   ```bash
   g++ backend/main.cpp -o server -std=c++17 -lssl -lcrypto -pthread -luuid
   ```

### 3️⃣ **Run the backend server**

```bash
./server
```

The server will be running on `http://localhost:3000`.

> **Console output:**
> ```
> Matchmaker running on port 3000
> ```

> **Backend endpoints:**
> - `POST /queue`
> - `GET /match/<ticket>`

### 4️⃣ **Expose the backend to Roblox**

Roblox cannot access `localhost` directly. You'll need to expose your local server to the internet.

**Option A (Recommended for local testing): `ngrok`**

```bash
ngrok http 3000
```

Copy the HTTPS URL (e.g., `https://abc123.ngrok.io`) and use it as the `BACKEND_URL` in your Roblox scripts.

**Option B (Production/VPS)**

> **Note:** Only after you implement game-ready changes.

- Deploy the backend to a public server (DigitalOcean, AWS, etc.).
- Open port `3000` in the firewall.
- Use the server’s IP/domain as the backend URL.

### 5️⃣ **Configure Roblox Scripts**

1. Copy the Lua files from `src/` into your Roblox game's `ServerScriptService` and `ServerStorage`.
2. Update the backend URL in `src/ServerStorage/MatchmakingClient/init.lua`:

```lua
local BACKEND_URL = "https://YOUR_PUBLIC_URL_OR_NGROK_URL"
```

3. Test by running multiple players in Roblox Studio.

---

## 📜 Important Notes

- 🔹 This is a **learning/prototyping project only**.
- 🔹 The backend is a **single instance**. All Roblox servers must point to the same backend for global matchmaking.
- 🔹 Consider adding: **timeouts, persistent storage, and scaling** for production use.

---

## 💡 Tips

- Use `ngrok` for quick and easy testing.
- Keep matchmaking parameters configurable.
- Log all matchmaking activity for easier debugging.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/rain-lua/RMatchmakerC/issues).

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.