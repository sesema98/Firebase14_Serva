//
//  TeacherHubView.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 7/2/26.
//

import SwiftUI
import Combine
import FirebaseAuth

private let aiAPIKeyAccount = "docentehub-ai-api-key"
private let defaultAIBaseURL = "http://192.168.17.11:3000"
private let defaultAIApiKey = ""
private let defaultAIModel = "Tecsup/schedule"

private enum HubSection: String, CaseIterable, Identifiable {
    case home
    case chat
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Inicio"
        case .chat:
            return "Chat IA"
        case .settings:
            return "Configuración"
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .chat:
            return "bubble.left.and.bubble.right.fill"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

private enum HubPalette {
    static let backgroundTop = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let backgroundBottom = Color(red: 0.05, green: 0.06, blue: 0.08)
    static let surface = Color.white.opacity(0.08)
    static let surfaceStrong = Color.white.opacity(0.12)
    static let outline = Color.white.opacity(0.08)
    static let accent = Color(red: 0.16, green: 0.73, blue: 0.56)
    static let accentSoft = Color(red: 0.16, green: 0.73, blue: 0.56).opacity(0.18)
    static let textSecondary = Color.white.opacity(0.64)
}

struct TeacherHubView: View {
    let currentUser: User
    let onSignOut: () -> Void

    @AppStorage("docentehub.ai.baseURL") private var aiBaseURL = ""
    @AppStorage("docentehub.ai.preferredModel") private var preferredModel = ""

    @StateObject private var teacherService = TeacherService()
    @StateObject private var chatViewModel = AIChatViewModel()

    @State private var selectedSection: HubSection = .home
    @State private var selectedTeacher: Teacher?
    @State private var departmentQuery = ""
    @State private var chatDraft = ""
    @State private var showingTeacherForm = false
    @State private var alertMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            background

            Group {
                switch selectedSection {
                case .home:
                    HomeScreenView(
                        currentUser: currentUser,
                        teacherService: teacherService,
                        departmentQuery: $departmentQuery,
                        onAddTeacher: {
                            showingTeacherForm = true
                        },
                        onAskTeacher: { teacher in
                            selectedTeacher = teacher
                            chatDraft = "¿Cuál es el horario de \(teacher.fullName)?"
                            selectedSection = .chat
                        }
                    )
                case .chat:
                    AIChatScreenView(
                        teacherService: teacherService,
                        viewModel: chatViewModel,
                        selectedTeacher: $selectedTeacher,
                        draftMessage: $chatDraft,
                        baseURL: aiBaseURL,
                        preferredModel: preferredModel,
                        apiKeyProvider: currentAPIKey,
                        onOpenSettings: {
                            selectedSection = .settings
                        }
                    )
                case .settings:
                    SettingsScreenView(
                        currentUser: currentUser,
                        onSignOut: onSignOut
                    )
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))

            FloatingMiniMenu(selectedSection: $selectedSection)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 92)
        }
        .sheet(isPresented: $showingTeacherForm) {
            TeacherFormView(teacherService: teacherService)
        }
        .alert("DocenteHub", isPresented: Binding(
            get: { alertMessage != nil },
            set: { newValue in
                if !newValue {
                    alertMessage = nil
                    teacherService.errorMessage = nil
                }
            }
        )) {
            Button("OK") {
                alertMessage = nil
                teacherService.errorMessage = nil
            }
        } message: {
            Text(alertMessage ?? "Ocurrió un error.")
        }
        .onAppear {
            if aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                aiBaseURL = defaultAIBaseURL
            }

            if preferredModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                preferredModel = defaultAIModel
            }

            if teacherService.teachers.isEmpty {
                teacherService.loadAllTeachers()
            }
        }
        .onChange(of: teacherService.errorMessage) { _, newValue in
            alertMessage = newValue
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedSection)
    }

    private var background: some View {
        LinearGradient(
            colors: [HubPalette.backgroundTop, HubPalette.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func currentAPIKey() -> String {
        KeychainService.load(account: aiAPIKeyAccount) ?? defaultAIApiKey
    }
}

@MainActor
private final class AIChatViewModel: ObservableObject {
    @Published private(set) var messages: [AIChatMessage] = [
        AIChatMessage(
            role: .assistant,
            text: "Pregunta por el horario de un docente, un curso o un aula."
        )
    ]
    @Published var isLoading = false

    private let aiService = AIService()

    func send(
        question: String,
        teacher: Teacher?,
        baseURL: String,
        apiKey: String,
        preferredModel: String
    ) async {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuestion.isEmpty else {
            return
        }

        messages.append(AIChatMessage(role: .user, text: trimmedQuestion))
        isLoading = true

        do {
            let response = try await aiService.ask(
                question: trimmedQuestion,
                teacher: teacher,
                baseURL: baseURL,
                apiKey: apiKey,
                preferredModel: preferredModel
            )
            messages.append(AIChatMessage(role: .assistant, text: response))
        } catch {
            messages.append(AIChatMessage(role: .system, text: error.localizedDescription))
        }

        isLoading = false
    }

    func reset() {
        messages = [
            AIChatMessage(
                role: .assistant,
                text: "Pregunta por el horario de un docente, un curso o un aula."
            )
        ]
    }
}

private struct AIChatMessage: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
        case system
    }

    let id = UUID()
    let role: Role
    let text: String
}

private struct FloatingMiniMenu: View {
    @Binding var selectedSection: HubSection

    var body: some View {
        HStack(spacing: 10) {
            ForEach(HubSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .font(.headline)
                        Text(section.title)
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(selectedSection == section ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selectedSection == section ? HubPalette.accent : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial.opacity(0.9))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(HubPalette.outline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.26), radius: 20, y: 8)
    }
}

private struct HomeScreenView: View {
    let currentUser: User
    @ObservedObject var teacherService: TeacherService
    @Binding var departmentQuery: String
    let onAddTeacher: () -> Void
    let onAskTeacher: (Teacher) -> Void
    @State private var pendingFilterTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleBar
                summaryCard
                queryCard
                teacherSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 72)
            .padding(.bottom, 110)
        }
        .onChange(of: departmentQuery) { _, newValue in
            scheduleAutomaticFilter(for: newValue)
        }
        .onDisappear {
            pendingFilterTask?.cancel()
        }
    }

    private var titleBar: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DocenteHub")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(currentUser.email ?? "usuario@tecsup.edu.pe")
                    .font(.subheadline)
                    .foregroundStyle(HubPalette.textSecondary)
            }

            Spacer()

            Circle()
                .fill(HubPalette.accentSoft)
                .frame(width: 46, height: 46)
                .overlay {
                    Text(initials(from: currentUser.email))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(HubPalette.accent)
                }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Directorio y consultas")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                statCard(title: "Docentes", value: "\(teacherService.teachers.count)")
                statCard(title: "Vista", value: currentQueryLabel)
                statCard(title: "IA", value: "Online")
            }

            HStack(spacing: 8) {
                statusPill(title: "Google", tone: .green)
                statusPill(title: "Firestore", tone: .blue)
                statusPill(title: "Horarios IA", tone: .mint)
            }

            HStack(spacing: 10) {
                ghostActionButton(title: "Agregar", systemImage: "plus", action: onAddTeacher)
                ghostActionButton(title: "Demo", systemImage: "sparkles") {
                    teacherService.addSampleTeachers()
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var queryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Filtros")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Departamento")
                        .font(.subheadline)
                        .foregroundStyle(HubPalette.textSecondary)

                    Spacer()

                    Text("WHERE automático")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(HubPalette.accent)
                }

                TextField("Escribe para filtrar...", text: $departmentQuery)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(HubPalette.outline, lineWidth: 1)
                    }
                    .foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                primaryPillButton(title: "Recientes (Top 3)") {
                    teacherService.loadRecentTeachers(limit: 3)
                }

                secondaryPillButton(title: "Todos") {
                    teacherService.loadAllTeachers()
                    departmentQuery = ""
                }
            }

            HStack(spacing: 8) {
                queryPill(title: "WHERE department")
                queryPill(title: "ORDER BY createdAt DESC")
                queryPill(title: "LIMIT 3")
            }

            Text(teacherService.queryDescription)
                .font(.caption)
                .foregroundStyle(HubPalette.textSecondary)
        }
        .padding(20)
        .background(cardBackground)
    }

    private var teacherSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Docentes")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if teacherService.isLoading {
                    ProgressView()
                        .tint(HubPalette.accent)
                }
            }

            if teacherService.isLoading && teacherService.teachers.isEmpty {
                loadingCard
            } else if teacherService.teachers.isEmpty {
                emptyCard
            } else {
                ForEach(teacherService.teachers) { teacher in
                    TeacherDirectoryCard(teacher: teacher) {
                        onAskTeacher(teacher)
                    }
                }
            }
        }
    }

    private var loadingCard: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(HubPalette.surface)
            .frame(height: 180)
            .overlay {
                ProgressView("Cargando docentes...")
                    .tint(HubPalette.accent)
                    .foregroundStyle(.white)
            }
    }

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.sequence.fill")
                .font(.largeTitle)
                .foregroundStyle(HubPalette.accent)

            Text("No hay docentes en esta vista")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Agrega registros nuevos o carga la data demo.")
                .font(.subheadline)
                .foregroundStyle(HubPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(cardBackground)
    }

    private var currentQueryLabel: String {
        if teacherService.queryDescription.localizedCaseInsensitiveContains("where") {
            return "Filtro"
        }

        if teacherService.queryDescription.localizedCaseInsensitiveContains("limit") {
            return "Top"
        }

        return "Todo"
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(HubPalette.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(HubPalette.outline, lineWidth: 1)
            }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(HubPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(HubPalette.surfaceStrong)
        )
    }

    private func statusPill(title: String, tone: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tone)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
    }

    private func queryPill(title: String) -> some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(HubPalette.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
            )
    }

    private func initials(from email: String?) -> String {
        guard let first = email?.first else {
            return "T"
        }

        return String(first).uppercased()
    }

    private func ghostActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HubPalette.outline, lineWidth: 1)
        }
    }

    private func primaryPillButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.black)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(HubPalette.accent)
        )
    }

    private func secondaryPillButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HubPalette.outline, lineWidth: 1)
        }
    }

    private func scheduleAutomaticFilter(for value: String) {
        pendingFilterTask?.cancel()

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty else {
            teacherService.loadAllTeachers()
            return
        }

        pendingFilterTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)

            guard !Task.isCancelled else {
                return
            }

            teacherService.loadTeachers(forDepartment: trimmedValue)
        }
    }
}

private struct TeacherDirectoryCard: View {
    let teacher: Teacher
    let onAskSchedule: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(HubPalette.accentSoft)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(initials)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(HubPalette.accent)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(teacher.fullName)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(teacher.email)
                        .font(.subheadline)
                        .foregroundStyle(HubPalette.textSecondary)
                }

                Spacer()

                Text(teacher.department)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(HubPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(HubPalette.accentSoft)
                    )
            }

            HStack {
                Label(teacher.office, systemImage: "building.2")
                    .font(.subheadline)
                    .foregroundStyle(HubPalette.textSecondary)

                Spacer()

                Button(action: onAskSchedule) {
                    Label("Horario", systemImage: "sparkles")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(HubPalette.accent)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(HubPalette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(HubPalette.outline, lineWidth: 1)
                }
        )
    }

    private var initials: String {
        teacher.fullName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

private struct AIChatScreenView: View {
    @ObservedObject var teacherService: TeacherService
    @ObservedObject var viewModel: AIChatViewModel
    @Binding var selectedTeacher: Teacher?
    @Binding var draftMessage: String
    let baseURL: String
    let preferredModel: String
    let apiKeyProvider: () -> String
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
                .padding(.horizontal, 20)
                .padding(.top, 72)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if viewModel.messages.count <= 1 {
                            suggestionStrip
                        }

                        if let selectedTeacher {
                            teacherContextChip(for: selectedTeacher)
                        }

                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isLoading {
                                TypingBubbleView()
                                    .id("typing")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 180)
                }
                .onChange(of: viewModel.messages) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.isLoading) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            chatComposer
                .padding(.horizontal, 14)
                .padding(.bottom, 92)
                .background(Color.clear)
        }
    }

    private var chatHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chat IA")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(connectionSummary)
                        .font(.subheadline)
                        .foregroundStyle(HubPalette.textSecondary)
                }

                Spacer()

                Button {
                    viewModel.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }

            if !isConfigured {
                Button(action: onOpenSettings) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Falta configurar la IA")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.orange.opacity(0.18))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestionStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sugerencias")
                .font(.headline)
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            draftMessage = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !teacherService.teachers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(teacherService.teachers.prefix(8)) { teacher in
                            Button {
                                selectedTeacher = teacher
                                draftMessage = "¿Cuál es el horario de \(teacher.fullName)?"
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.crop.circle")
                                    Text(teacher.fullName)
                                }
                                .font(.subheadline)
                                .foregroundStyle(HubPalette.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(HubPalette.accentSoft)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func teacherContextChip(for teacher: Teacher) -> some View {
        HStack(spacing: 10) {
            Label("Contexto: \(teacher.fullName)", systemImage: "person.text.rectangle")
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer()

            Button("Quitar") {
                selectedTeacher = nil
            }
            .font(.subheadline)
            .foregroundStyle(HubPalette.accent)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var chatComposer: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Pregunta por un docente, curso o aula...", text: $draftMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1 ... 5)
                    .foregroundStyle(.white)

                Button {
                    sendCurrentMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(sendDisabled ? Color.white.opacity(0.18) : HubPalette.accent)
                        )
                }
                .buttonStyle(.plain)
                .disabled(sendDisabled)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial.opacity(0.9))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(HubPalette.outline, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.24), radius: 16, y: 8)
        }
    }

    private var sendDisabled: Bool {
        draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isConfigured || viewModel.isLoading
    }

    private var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKeyProvider().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var connectionSummary: String {
        if let host = URL(string: baseURL)?.host(), !host.isEmpty {
            return host
        }

        return "Servidor IA"
    }

    private var suggestions: [String] {
        if let teacher = selectedTeacher {
            return [
                "¿Cuál es el horario de \(teacher.fullName)?",
                "¿En qué aula dicta clases \(teacher.fullName)?",
                "¿Qué cursos tiene \(teacher.fullName) esta semana?"
            ]
        }

        let teacherNames = teacherService.teachers.prefix(2).map(\.fullName)

        if teacherNames.count == 2 {
            return [
                "¿Cuál es el horario de \(teacherNames[0])?",
                "¿En qué aula dicta clases \(teacherNames[1])?",
                "¿Qué docente dicta Sistemas Operativos?"
            ]
        }

        return [
            "¿Cuál es el horario de Sigueñas Siaden, Luis Manuel?",
            "¿Qué docente dicta Sistemas Operativos?",
            "¿En qué aula se dicta la clase del viernes?"
        ]
    }

    private func sendCurrentMessage() {
        let currentMessage = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = apiKeyProvider().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !currentMessage.isEmpty, !apiKey.isEmpty else {
            return
        }

        draftMessage = ""

        Task {
            await viewModel.send(
                question: currentMessage,
                teacher: selectedTeacher,
                baseURL: baseURL,
                apiKey: apiKey,
                preferredModel: preferredModel
            )
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessageID = viewModel.messages.last?.id else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.22)) {
                if viewModel.isLoading {
                    proxy.scrollTo("typing", anchor: .bottom)
                } else {
                    proxy.scrollTo(lastMessageID, anchor: .bottom)
                }
            }
        }
    }
}

private struct ChatBubbleView: View {
    let message: AIChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.role != .user {
                bubbleIcon
            } else {
                Spacer(minLength: 42)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                bubbleContent
                    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white.opacity(0.9))
                    }
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var bubbleIcon: some View {
        Circle()
            .fill(message.role == .assistant ? HubPalette.accentSoft : Color.red.opacity(0.18))
            .frame(width: 34, height: 34)
            .overlay {
                Image(systemName: message.role == .assistant ? "sparkles" : "exclamationmark.triangle.fill")
                    .foregroundStyle(message.role == .assistant ? HubPalette.accent : .red)
            }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.role {
        case .user:
            Text(message.text)
                .font(.body)
                .foregroundStyle(textColor)
                .multilineTextAlignment(.leading)

        case .assistant:
            if let schedule = AssistantScheduleFormatter.parse(message.text) {
                AssistantScheduleView(schedule: schedule)
            } else {
                MarkdownBubbleTextView(text: message.text, color: textColor)
            }

        case .system:
            MarkdownBubbleTextView(text: message.text, color: textColor)
        }
    }

    private var bubbleBackground: some ShapeStyle {
        switch message.role {
        case .user:
            return AnyShapeStyle(Color.white.opacity(0.08))
        case .assistant:
            return AnyShapeStyle(Color.white.opacity(0.04))
        case .system:
            return AnyShapeStyle(Color.red.opacity(0.12))
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user, .assistant:
            return .white
        case .system:
            return Color(red: 1.0, green: 0.82, blue: 0.82)
        }
    }
}

private struct MarkdownBubbleTextView: View {
    let text: String
    let color: Color

    var body: some View {
        if let markdown = try? AttributedString(markdown: normalizedMarkdown) {
            Text(markdown)
                .font(.body)
                .foregroundStyle(color)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        } else {
            Text(normalizedMarkdown)
                .font(.body)
                .foregroundStyle(color)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
    }

    private var normalizedMarkdown: String {
        text
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "* **", with: "**")
            .replacingOccurrences(of: "•", with: "-")
    }
}

private struct AssistantScheduleView: View {
    let schedule: AssistantScheduleFormatter.Schedule

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !schedule.title.isEmpty {
                Text(schedule.title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            ForEach(schedule.summaryLines, id: \.self) { line in
                summaryRow(line)
            }

            ForEach(schedule.sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(HubPalette.accent)
                            .frame(width: 8, height: 8)

                        Text(section.title)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(section.items, id: \.self) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundStyle(HubPalette.accent)
                                    .padding(.top, 4)

                                Text(item)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.94))
                            }
                        }
                    }
                    .padding(.leading, 2)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }

            if let sourceLine = schedule.sourceLine {
                Text(sourceLine)
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(HubPalette.textSecondary)
            }
        }
        .textSelection(.enabled)
    }

    private func summaryRow(_ line: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bookmark.fill")
                .font(.caption)
                .foregroundStyle(HubPalette.accent)
                .padding(.top, 4)

            Text(line)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.94))
        }
    }
}

private enum AssistantScheduleFormatter {
    struct Schedule {
        let title: String
        let summaryLines: [String]
        let sections: [Section]
        let sourceLine: String?
    }

    struct Section: Identifiable {
        let id = UUID()
        let title: String
        let items: [String]
    }

    nonisolated static func parse(_ text: String) -> Schedule? {
        let cleanedLines = text
            .replacingOccurrences(of: "\r", with: "")
            .components(separatedBy: .newlines)
            .map(cleanLine)
            .filter { !$0.isEmpty }

        guard !cleanedLines.isEmpty else {
            return nil
        }

        var title = ""
        var summaryLines: [String] = []
        var sections: [Section] = []
        var sourceLine: String?
        var currentSectionTitle: String?
        var currentItems: [String] = []

        for line in cleanedLines {
            if isSourceLine(line) {
                flushSection(into: &sections, title: &currentSectionTitle, items: &currentItems)
                sourceLine = line
                continue
            }

            if isDayLine(line) {
                flushSection(into: &sections, title: &currentSectionTitle, items: &currentItems)
                currentSectionTitle = normalizedDayTitle(from: line)
                continue
            }

            if currentSectionTitle == nil {
                if title.isEmpty {
                    title = line
                } else {
                    summaryLines.append(line)
                }
            } else {
                currentItems.append(cleanScheduleItem(line))
            }
        }

        flushSection(into: &sections, title: &currentSectionTitle, items: &currentItems)

        guard !sections.isEmpty else {
            return nil
        }

        return Schedule(
            title: title,
            summaryLines: summaryLines,
            sections: sections,
            sourceLine: sourceLine
        )
    }

    nonisolated private static func cleanLine(_ value: String) -> String {
        var line = value.trimmingCharacters(in: .whitespacesAndNewlines)
        line = line.replacingOccurrences(of: "**", with: "")

        while line.hasPrefix("*") || line.hasPrefix("-") || line.hasPrefix("•") {
            line.removeFirst()
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return line
    }

    nonisolated private static func isDayLine(_ line: String) -> Bool {
        let normalized = normalizedDayTitle(from: line)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: ":", with: "")

        return [
            "lunes",
            "martes",
            "miercoles",
            "jueves",
            "viernes",
            "sabado",
            "domingo"
        ].contains(normalized)
    }

    nonisolated private static func normalizedDayTitle(from line: String) -> String {
        line.trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespacesAndNewlines))
    }

    nonisolated private static func cleanScheduleItem(_ line: String) -> String {
        line.trimmingCharacters(in: CharacterSet(charactersIn: "-• ").union(.whitespacesAndNewlines))
    }

    nonisolated private static func isSourceLine(_ line: String) -> Bool {
        line.localizedCaseInsensitiveContains("fuente:")
    }

    nonisolated private static func flushSection(
        into sections: inout [Section],
        title: inout String?,
        items: inout [String]
    ) {
        guard let title, !items.isEmpty else {
            items.removeAll()
            return
        }

        sections.append(Section(title: title, items: items))
        items.removeAll()
    }
}

private struct TypingBubbleView: View {
    @State private var pulse = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Circle()
                .fill(HubPalette.accentSoft)
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "sparkles")
                        .foregroundStyle(HubPalette.accent)
                }

            HStack(spacing: 8) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Circle()
                        .fill(HubPalette.textSecondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulse ? 1 : 0.65)
                        .animation(
                            .easeInOut(duration: 0.55)
                            .repeatForever()
                            .delay(Double(index) * 0.12),
                            value: pulse
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )

            Spacer()
        }
        .onAppear {
            pulse = true
        }
    }
}

private struct SettingsScreenView: View {
    let currentUser: User
    let onSignOut: () -> Void

    @AppStorage("docentehub.ai.baseURL") private var aiBaseURL = ""
    @AppStorage("docentehub.ai.preferredModel") private var preferredModel = ""

    @State private var draftBaseURL = ""
    @State private var draftPreferredModel = ""
    @State private var draftAPIKey = ""
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsHeader
                connectionCard
                notesCard
                sessionCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 72)
            .padding(.bottom, 110)
        }
        .onAppear {
            if aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                aiBaseURL = defaultAIBaseURL
            }

            if preferredModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                preferredModel = defaultAIModel
            }

            draftBaseURL = aiBaseURL
            draftPreferredModel = preferredModel
            draftAPIKey = KeychainService.load(account: aiAPIKeyAccount) ?? defaultAIApiKey
        }
        .alert("Configuración", isPresented: Binding(
            get: { statusMessage != nil },
            set: { newValue in
                if !newValue {
                    statusMessage = nil
                }
            }
        )) {
            Button("OK") {
                statusMessage = nil
            }
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Configuración")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(currentUser.email ?? "usuario@tecsup.edu.pe")
                .font(.subheadline)
                .foregroundStyle(HubPalette.textSecondary)
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Servidor IA")
                .font(.headline)
                .foregroundStyle(.white)

            field(title: "URL base", text: $draftBaseURL, placeholder: "http://192.168.17.11:3000", secure: false)
            field(title: "Modelo preferido", text: $draftPreferredModel, placeholder: defaultAIModel, secure: false)
            field(title: "API key", text: $draftAPIKey, placeholder: "sk-...", secure: true)

            HStack(spacing: 10) {
                actionButton(title: "Guardar", filled: true) {
                    saveSettings()
                }

                actionButton(title: "Borrar key", filled: false) {
                    KeychainService.delete(account: aiAPIKeyAccount)
                    draftAPIKey = ""
                    statusMessage = "La API key guardada se eliminó."
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conclusiones")
                .font(.headline)
                .foregroundStyle(.white)

            noteRow("Al registrar y filtrar docentes en Firestore me di cuenta de que conviene guardar ahi la informacion estructurada, porque asi las consultas por carrera y los listados recientes responden rapido y sin depender de la IA.")
            noteRow("Al conectar el chat con el modelo para preguntar por horarios note que la experiencia mejora bastante cuando la base de datos y la IA tienen roles separados: Firestore organiza los docentes y la IA resuelve preguntas en lenguaje natural de forma mas practica para el usuario.")
        }
        .padding(20)
        .background(cardBackground)
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sesión")
                .font(.headline)
                .foregroundStyle(.white)

            Button(action: onSignOut) {
                Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.red.opacity(0.18))
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
        .padding(20)
        .background(cardBackground)
    }

    @ViewBuilder
    private func field(title: String, text: Binding<String>, placeholder: String, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(HubPalette.textSecondary)

            if secure {
                SecureField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(inputBackground)
            } else {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(inputBackground)
            }
        }
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HubPalette.outline, lineWidth: 1)
            }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(HubPalette.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(HubPalette.outline, lineWidth: 1)
            }
    }

    private func noteRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(HubPalette.accent)
                .padding(.top, 2)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }

    private func actionButton(title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(filled ? .black : .white)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(filled ? AnyShapeStyle(HubPalette.accent) : AnyShapeStyle(Color.white.opacity(0.06)))
        )
        .overlay {
            if !filled {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HubPalette.outline, lineWidth: 1)
            }
        }
    }

    private func saveSettings() {
        aiBaseURL = sanitizeBaseURL(draftBaseURL)
        preferredModel = draftPreferredModel.trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedAPIKey = draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedAPIKey.isEmpty {
            KeychainService.delete(account: aiAPIKeyAccount)
        } else {
            _ = KeychainService.save(value: trimmedAPIKey, account: aiAPIKeyAccount)
        }

        statusMessage = "La configuración se guardó."
    }

    private func sanitizeBaseURL(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }
}

struct TeacherFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var teacherService: TeacherService

    @State private var fullName = ""
    @State private var email = ""
    @State private var department = ""
    @State private var office = ""
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [HubPalette.backgroundTop, HubPalette.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Nuevo docente")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 14) {
                            teacherField("Nombre completo", text: $fullName)
                            teacherField("Correo", text: $email, keyboard: .emailAddress, autocapitalize: false)
                            teacherField("Departamento", text: $department)
                            teacherField("Oficina", text: $office)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(HubPalette.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(HubPalette.outline, lineWidth: 1)
                                }
                        )

                        Button {
                            teacherService.addTeacher(
                                fullName: fullName,
                                email: email,
                                department: department,
                                office: office
                            ) { success in
                                if success {
                                    dismiss()
                                } else {
                                    showingError = true
                                }
                            }
                        } label: {
                            Text("Guardar docente")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(HubPalette.accent)
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.black)
                    }
                    .padding(20)
                    .padding(.top, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .alert("Docente", isPresented: $showingError) {
                Button("OK") {
                    teacherService.errorMessage = nil
                }
            } message: {
                Text(teacherService.errorMessage ?? "No se pudo guardar el docente.")
            }
        }
    }

    private func teacherField(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        autocapitalize: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(HubPalette.textSecondary)

            TextField(title, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalize ? .words : .never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(HubPalette.outline, lineWidth: 1)
                        }
                )
        }
    }
}
