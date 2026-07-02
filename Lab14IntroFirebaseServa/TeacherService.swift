//
//  TeacherService.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 7/2/26.
//

import Foundation
import Combine
import FirebaseFirestore

final class TeacherService: ObservableObject {
    @Published private(set) var teachers: [Teacher] = []
    @Published private(set) var queryDescription = "ORDER BY createdAt DESC • listado completo"
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let teachersCollection = Firestore.firestore().collection("teachers")

    func loadAllTeachers() {
        runQuery(
            description: "ORDER BY createdAt DESC • listado completo",
            query: teachersCollection.order(by: "createdAt", descending: true)
        )
    }

    func loadTeachers(forDepartment department: String) {
        let normalizedDepartment = Teacher.normalizedDepartment(department)

        guard !normalizedDepartment.isEmpty else {
            errorMessage = "Ingresa un departamento antes de ejecutar la consulta WHERE."
            return
        }

        runQuery(
            description: "WHERE departmentKey == '\(normalizedDepartment)' • filtro por departamento",
            query: teachersCollection.whereField("departmentKey", isEqualTo: normalizedDepartment),
            transform: {
                $0.sorted { $0.createdAt > $1.createdAt }
            }
        )
    }

    func loadRecentTeachers(limit: Int = 3) {
        runQuery(
            description: "ORDER BY createdAt DESC LIMIT \(limit) • docentes recientes",
            query: teachersCollection
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
        )
    }

    func addTeacher(
        fullName: String,
        email: String,
        department: String,
        office: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        let teacher = Teacher(
            fullName: fullName,
            email: email,
            department: department,
            office: office
        )

        guard validate(teacher: teacher) else {
            completion?(false)
            return
        }

        isLoading = true
        errorMessage = nil

        let document = teachersCollection.document()

        document.setData(teacher.firestoreData) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error {
                    self?.errorMessage = "No se pudo guardar el docente: \(error.localizedDescription)"
                    completion?(false)
                    return
                }

                self?.loadAllTeachers()
                completion?(true)
            }
        }
    }

    func addSampleTeachers() {
        isLoading = true
        queryDescription = "INSERT sample teachers"
        errorMessage = nil

        let sampleTeachers = [
            Teacher(
                id: "teacher-demo-1",
                fullName: "Juan Gómez",
                email: "jgomez@tecsup.edu.pe",
                department: "Computación",
                office: "A-201",
                createdAt: Date()
            ),
            Teacher(
                id: "teacher-demo-2",
                fullName: "María Torres",
                email: "mtorres@tecsup.edu.pe",
                department: "Electrónica",
                office: "B-105",
                createdAt: Date().addingTimeInterval(-4_200)
            ),
            Teacher(
                id: "teacher-demo-3",
                fullName: "Luis Herrera",
                email: "lherrera@tecsup.edu.pe",
                department: "Computación",
                office: "A-305",
                createdAt: Date().addingTimeInterval(-8_400)
            ),
            Teacher(
                id: "teacher-demo-4",
                fullName: "Paola Ruiz",
                email: "pruiz@tecsup.edu.pe",
                department: "Mecatrónica",
                office: "C-110",
                createdAt: Date().addingTimeInterval(-12_600)
            )
        ]

        let batch = Firestore.firestore().batch()

        for teacher in sampleTeachers {
            let document = teachersCollection.document(teacher.id)
            batch.setData(teacher.firestoreData, forDocument: document, merge: true)
        }

        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.isLoading = false
                    self?.errorMessage = "No se pudo cargar la data demo: \(error.localizedDescription)"
                    return
                }

                self?.loadAllTeachers()
            }
        }
    }

    private func runQuery(
        description: String,
        query: Query,
        transform: (([Teacher]) -> [Teacher])? = nil
    ) {
        isLoading = true
        queryDescription = description
        errorMessage = nil

        query.getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error {
                    self?.teachers = []
                    self?.errorMessage = Self.userFacingMessage(for: error)
                    return
                }

                let teachers = snapshot?.documents.compactMap(Teacher.from) ?? []
                self?.teachers = transform?(teachers) ?? teachers
            }
        }
    }

    private func validate(teacher: Teacher) -> Bool {
        guard
            !teacher.fullName.isEmpty,
            !teacher.email.isEmpty,
            !teacher.department.isEmpty,
            !teacher.office.isEmpty
        else {
            errorMessage = "Completa nombre, correo, departamento y oficina."
            return false
        }

        guard teacher.email.contains("@") else {
            errorMessage = "Ingresa un correo válido para el docente."
            return false
        }

        return true
    }

    private static func userFacingMessage(for error: Error) -> String {
        let message = error.localizedDescription

        if message.localizedCaseInsensitiveContains("permission denied") {
            return "Firestore rechazó la operación por reglas de seguridad. Verifica que usuarios autenticados puedan leer y escribir en la colección teachers."
        }

        if message.localizedCaseInsensitiveContains("index") {
            return "Firestore necesita un índice para completar la consulta solicitada. Crea el índice sugerido por Firebase Console o usa la consulta básica."
        }

        return "La operación en Firestore falló: \(message)"
    }
}
