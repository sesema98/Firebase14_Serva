//
//  QueryTestView.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 6/22/26.
//

import SwiftUI

struct QueryTestView: View {
    @StateObject private var queryService = PostQueryService()
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 12) {
            if !queryService.queryDescription.isEmpty {
                VStack(spacing: 6) {
                    Text("Consulta actual")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(queryService.queryDescription)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            ScrollView {
                VStack(spacing: 16) {
                    querySection(title: "Consultas requeridas") {
                        queryButton("Todos los posts", color: .blue) {
                            queryService.getAllPosts()
                        }

                        queryButton("Más populares", color: .orange) {
                            queryService.getPopularPosts()
                        }

                        queryButton("Top 5 populares", color: .red) {
                            queryService.getTop5PopularPosts()
                        }
                    }

                    querySection(title: "Consultas extra") {
                        queryButton("Swift", color: .teal) {
                            queryService.getPostsByCategory("swift")
                        }

                        queryButton("Más nuevos", color: .indigo) {
                            queryService.getPostsByNewest()
                        }

                        queryButton("Primeros 3", color: .brown) {
                            queryService.getFirst3Posts()
                        }
                    }

                    querySection(title: "Utilidades") {
                        queryButton("Agregar data", color: .gray) {
                            queryService.addSamplePosts()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            Group {
                if queryService.isLoading {
                    ProgressView("Consultando Firestore...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if queryService.posts.isEmpty {
                    ContentUnavailableView(
                        "Sin resultados",
                        systemImage: "magnifyingglass",
                        description: Text("Ejecuta una consulta o agrega datos de prueba.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(queryService.posts) { post in
                        PostRowView(post: post)
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Consultas")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: queryService.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
        .alert("Firestore Queries", isPresented: $showingError) {
            Button("OK") {
                queryService.errorMessage = nil
            }
        } message: {
            Text(queryService.errorMessage ?? "Ocurrió un error al consultar Firestore.")
        }
    }

    private func querySection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func queryButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct PostRowView: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.title)
                        .font(.headline)

                    Text(post.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Text(post.category.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor(post.category))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                Text(post.authorEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Label("\(post.likes)", systemImage: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.red)

                Text(post.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "swift":
            return .blue
        case "kotlin":
            return .orange
        case "google":
            return .green
        default:
            return .gray
        }
    }
}

#Preview {
    NavigationStack {
        QueryTestView()
    }
}
