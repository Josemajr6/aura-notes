import SwiftUI
import SwiftData

@main
struct AuraNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        // Configuración de la base de datos (va en el WindowGroup)
        .modelContainer(for: Note.self)
        
        // Usamos HiddenTitleBarWindowStyle() explícitamente para quitar la barra gris.
        .windowStyle(HiddenTitleBarWindowStyle())
        
        // Permite mover la ventana arrastrando el fondo (solo funciona en macOS Sonoma+)
        // Si te da error, borra esta línea.
        .windowBackgroundDragBehavior(.enabled)
    }
}
