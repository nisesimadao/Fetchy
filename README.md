# Fetchy

![SwiftUI](https://img.shields.io/badge/SwiftUI-5-orange.svg)
![Node.js](https://img.shields.io/badge/Node.js-16+-green.svg)
![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg)

A modern iOS video downloader powered by a Node.js backend and `yt-dlp`.

Fetchy provides a seamless video downloading experience by offloading all heavy processing to a server, keeping the iOS app lightweight, fast, and battery-efficient.
[日本語Readmeはこっち](README-jp.md)
## 🖼️ Screenshots

<img width="195" alt="Shared Extension Download Screen" src="https://github.com/user-attachments/assets/91a0d835-5c03-4bfd-89ca-1e6bf27692b4" />
<img width="195" alt="Shared Extension Download Progress Screen (can be turned on/off in settings)" src="https://github.com/user-attachments/assets/73d8e366-b294-497f-aeb9-9c8c8ddec4aa" />
<img width="195" alt="Download Screen" src="https://github.com/user-attachments/assets/11280d76-10f2-4ca0-955f-2c8a6bdccab4" />
<img width="195" alt="History Screen" src="https://github.com/user-attachments/assets/a3e662be-aeb6-4668-99e1-edaaf4c78307" />


## ✨ Features

- **Server-Side Processing**: The backend handles `yt-dlp` execution, minimizing the iOS device's CPU and battery usage.
- **Wide Site Compatibility**: Supports downloading from hundreds of video sites thanks to `yt-dlp`.
- **Real-Time Progress**: The app's UI is updated in real-time by polling the backend for job status.
- **Rich Download Options**: Customize downloads with options for quality, format, metadata embedding, and more.
- **Native SwiftUI Interface**: A clean, modern, and responsive UI built entirely with SwiftUI.
- **Share Extension**: Start downloads directly from other apps (like Safari) via the iOS Share Sheet.
- **Asynchronous by Design**: The job-based architecture ensures the app remains responsive at all times.

## 🏗️ Architecture

Fetchy uses a client-server architecture to separate the user interface from the heavy lifting of video processing.

1.  **iOS App (Client)**: The user provides a video URL via the main app or the Share Extension.
2.  **API Request**: The app sends a "start download" request to the Node.js backend.
3.  **Node.js API (Server)**: The server creates a unique job ID, immediately starts a `yt-dlp` download process in the background, and returns the job ID to the app.
4.  **Polling for Status**: The iOS app periodically polls a status endpoint (`/api/status/:jobId`) to get real-time progress.
5.  **File Download**: Once the server finishes downloading the video, the iOS app downloads the final file from a dedicated endpoint (`/api/download/:jobId`).

```
+------------------+           +----------------------+           +----------------+
| iOS App (Client) | --(1)-->  | Node.js API (Server) | --(2)-->  | yt-dlp Process |
|                  | <-- JobID--|                      |           |                |
|                  |           |                      |           +----------------+
|   polls status  | --(3)-->  |  (manages job)       |
|                  | <--progress|                      |
|                  |           |                      |
| downloads file   | --(4)-->  |  (serves file)       |
+------------------+           +----------------------+
```

## 🛠️ Tech Stack

- **Client (iOS)**: SwiftUI
- **Server (Backend)**: Node.js, Express.js
- **Core Dependency**: `yt-dlp`

## 🚀 Setup & Installation

To run Fetchy, you need to set up both the backend server and the iOS client.

### 1. Backend Server (`fetchy-api`)

The server is responsible for handling API requests and running `yt-dlp`.

```bash
# 1. Navigate to the api directory
cd fetchy-api

# 2. Install dependencies
npm install

# 3. Start the server (defaults to port 3000)
npm start
```

For production use, you should deploy this backend to a hosting service like [Railway](https://railway.app/), Heroku, or Render. After deploying, you will get a public URL for your API.

### 2. iOS App (`Fetchy`)

The iOS app needs to know the URL of your backend server.

1.  Open the project in Xcode:
    ```bash
    open Fetchy.xcodeproj
    ```
2.  Navigate to the API client file: `Fetchy/Shared/Managers/APIClient.swift`.
3.  **Crucially, you must update the `baseURL` constant** to point to the public URL of your deployed backend server.
    ```swift
    // Fetchy/Shared/Managers/APIClient.swift

    // ‼️ Replace this with your own backend URL
    private let baseURL = "https://your-backend-service-url.com"
    ```
4.  Build and run the app on a simulator or a physical device.

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
