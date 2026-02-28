//
//  entrypoint.swift
//  NekkoBackend
//
//  Created by 湯川昇平 on 2026/02/28.
//

import Vapor

@main
struct NekkoBackendApp {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)
        defer { Task { try? await app.asyncShutdown() } }

        app.http.server.configuration.hostname = "0.0.0.0"
        app.http.server.configuration.port = 8080

        try routes(app)
        try await app.execute()
    }
}
