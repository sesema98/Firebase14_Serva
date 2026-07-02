//
//  AIService.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 7/2/26.
//

import Foundation

final class AIService {
    private var cachedModel: String?

    func ask(
        question: String,
        teacher: Teacher?,
        baseURL: String,
        apiKey: String,
        preferredModel: String
    ) async throws -> String {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseURL = sanitizedBaseURL(baseURL)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPreferredModel = preferredModel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuestion.isEmpty else {
            throw AIServiceError.invalidQuestion
        }

        guard !trimmedBaseURL.isEmpty else {
            throw AIServiceError.missingBaseURL
        }

        guard !trimmedAPIKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        guard !trimmedBaseURL.localizedCaseInsensitiveContains("localhost") else {
            throw AIServiceError.invalidBaseURL
        }

        let model = try await resolveModel(
            baseURL: trimmedBaseURL,
            apiKey: trimmedAPIKey,
            preferredModel: trimmedPreferredModel
        )

        let payload: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                [
                    "role": "system",
                    "content": """
                    Eres el asistente de DocenteHub. Responde en español y enfócate en consultas sobre horarios académicos de TECSUP.
                    Si el horario no está disponible en el modelo, dilo claramente y no inventes datos.
                    Si te preguntan por aulas, cursos o secciones, responde de forma directa y útil.
                    Cuando respondas con horarios, usa este formato limpio:
                    Título en una línea.
                    Carrera: ...
                    Día:
                    - HH:MM - HH:MM: detalle
                    No uses markdown roto ni listas anidadas extrañas.
                    """
                ],
                [
                    "role": "user",
                    "content": userPrompt(question: trimmedQuestion, teacher: teacher)
                ]
            ]
        ]

        let responseData = try await request(
            path: "/api/chat/completions",
            method: "POST",
            baseURL: trimmedBaseURL,
            apiKey: trimmedAPIKey,
            payload: payload
        )

        guard let content = extractContent(from: responseData) else {
            throw AIServiceError.invalidResponse
        }

        return content
    }

    private func resolveModel(
        baseURL: String,
        apiKey: String,
        preferredModel: String
    ) async throws -> String {
        if preferredModel.isEmpty, let cachedModel {
            return cachedModel
        }

        do {
            let responseData = try await request(
                path: "/api/models",
                method: "GET",
                baseURL: baseURL,
                apiKey: apiKey,
                payload: nil
            )

            let identifiers = extractModelIdentifiers(from: responseData)
            guard let model = selectModel(from: identifiers, preferredModel: preferredModel) else {
                throw AIServiceError.missingModel
            }

            if preferredModel.isEmpty {
                cachedModel = model
            }

            return model
        } catch {
            if !preferredModel.isEmpty {
                return preferredModel
            }

            throw error
        }
    }

    private func request(
        path: String,
        method: String,
        baseURL: String,
        apiKey: String,
        payload: [String: Any]?
    ) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw AIServiceError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let payload {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode, body: body)
        }

        return data
    }

    private func extractModelIdentifiers(from data: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        return modelIdentifiers(from: object)
    }

    private func modelIdentifiers(from object: Any) -> [String] {
        if let array = object as? [[String: Any]] {
            return array.compactMap(modelIdentifier)
        }

        if let dictionary = object as? [String: Any] {
            if let data = dictionary["data"] as? [[String: Any]] {
                return data.compactMap(modelIdentifier)
            }

            if let models = dictionary["models"] as? [[String: Any]] {
                return models.compactMap(modelIdentifier)
            }

            if let nestedArray = dictionary["items"] as? [[String: Any]] {
                return nestedArray.compactMap(modelIdentifier)
            }

            if let identifier = modelIdentifier(from: dictionary) {
                return [identifier]
            }
        }

        return []
    }

    private func modelIdentifier(from dictionary: [String: Any]) -> String? {
        if let id = dictionary["id"] as? String, !id.isEmpty {
            return id
        }

        if let name = dictionary["name"] as? String, !name.isEmpty {
            return name
        }

        if let model = dictionary["model"] as? String, !model.isEmpty {
            return model
        }

        return nil
    }

    private func extractContent(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let dictionary = object as? [String: Any] {
            if
                let choices = dictionary["choices"] as? [[String: Any]],
                let firstChoice = choices.first
            {
                if
                    let message = firstChoice["message"] as? [String: Any],
                    let content = extractText(from: message["content"]),
                    !content.isEmpty
                {
                    return content
                }

                if
                    let delta = firstChoice["delta"] as? [String: Any],
                    let content = extractText(from: delta["content"]),
                    !content.isEmpty
                {
                    return content
                }

                if
                    let text = firstChoice["text"] as? String,
                    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            if
                let message = dictionary["message"] as? [String: Any],
                let content = extractText(from: message["content"]),
                !content.isEmpty
            {
                return content
            }

            if
                let content = extractText(from: dictionary["content"]),
                !content.isEmpty
            {
                return content
            }
        }

        return nil
    }

    private func extractText(from value: Any?) -> String? {
        if let text = value as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let items = value as? [[String: Any]] {
            let text = items.compactMap { item -> String? in
                if let value = item["text"] as? String {
                    return value
                }

                if let value = item["content"] as? String {
                    return value
                }

                return nil
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

            return text.isEmpty ? nil : text
        }

        return nil
    }

    private func sanitizedBaseURL(_ baseURL: String) -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private func selectModel(from identifiers: [String], preferredModel: String) -> String? {
        let normalizedPreferredModel = preferredModel.trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalizedPreferredModel.isEmpty {
            if let exactMatch = identifiers.first(where: {
                $0.compare(normalizedPreferredModel, options: .caseInsensitive) == .orderedSame
            }) {
                return exactMatch
            }

            if let looseMatch = identifiers.first(where: {
                $0.localizedCaseInsensitiveContains(normalizedPreferredModel)
                    || normalizedPreferredModel.localizedCaseInsensitiveContains($0)
            }) {
                return looseMatch
            }

            return normalizedPreferredModel
        }

        if let tecsupSchedule = identifiers.first(where: {
            $0.localizedCaseInsensitiveContains("tecsup/schedule")
        }) {
            return tecsupSchedule
        }

        if let scheduleModel = identifiers.first(where: {
            $0.localizedCaseInsensitiveContains("schedule")
        }) {
            return scheduleModel
        }

        if let gemmaModel = identifiers.first(where: {
            $0.localizedCaseInsensitiveContains("gemma")
        }) {
            return gemmaModel
        }

        return identifiers.first
    }

    private func userPrompt(question: String, teacher: Teacher?) -> String {
        guard let teacher else {
            return """
            Pregunta:
            \(question)
            """
        }

        return """
        Contexto del docente seleccionado:
        - Nombre: \(teacher.fullName)
        - Correo: \(teacher.email)
        - Departamento: \(teacher.department)
        - Oficina: \(teacher.office)

        Pregunta:
        \(question)
        """
    }
}

enum AIServiceError: LocalizedError {
    case invalidQuestion
    case missingBaseURL
    case invalidBaseURL
    case missingAPIKey
    case missingModel
    case invalidResponse
    case serverError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidQuestion:
            return "Escribe una pregunta antes de consultar el horario."
        case .missingBaseURL:
            return "Configura la IP o URL base del servidor Gemma/OpenWebUI."
        case .invalidBaseURL:
            return "La URL del servidor es inválida. Usa una IP real del servidor y no localhost."
        case .missingAPIKey:
            return "Configura la API key de OpenWebUI antes de consultar horarios."
        case .missingModel:
            return "No se encontró un modelo disponible en OpenWebUI. Verifica que Gemma esté cargado en el servidor."
        case .invalidResponse:
            return "La IA respondió con un formato no esperado."
        case let .serverError(statusCode, body):
            let details = body.isEmpty ? "Sin detalle adicional." : body
            return "La IA devolvió HTTP \(statusCode): \(details)"
        }
    }
}
