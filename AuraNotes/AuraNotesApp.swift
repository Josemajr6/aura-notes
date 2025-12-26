//
//  AuraNotesApp.swift
//  AuraNotes
//
//  Created by José Manuel Jiménez Rodríguez on 22/12/25.
//

import SwiftUI
import SwiftData // 1. Solución al primer error: Importar SwiftData

@main
struct AuraNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 2. Solución al segundo error:
                // El modo oscuro se aplica AQUÍ, directo a la vista, no al grupo.
                .preferredColorScheme(.dark)
        }
        // Configuración de la base de datos (va en el WindowGroup)
        .modelContainer(for: Note.self)
        
        // 3. Solución al estilo de ventana:
        // Usamos HiddenTitleBarWindowStyle() explícitamente para quitar la barra gris.
        .windowStyle(HiddenTitleBarWindowStyle())
        
        // Permite mover la ventana arrastrando el fondo (solo funciona en macOS Sonoma+)
        // Si te da error, borra esta línea.
        .windowBackgroundDragBehavior(.enabled)
    }
}
