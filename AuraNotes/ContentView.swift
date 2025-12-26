import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.timestamp, order: .reverse) private var notes: [Note]
    
    // --- ESTADOS DE SELECCIÓN ---
    @State private var selectedNote: Note?
    @State private var isShowingNoteList: Bool = false
    @State private var isShowingSettings: Bool = false
    
    // --- ESTADOS DEL EDITOR ---
    @State private var editorAction: EditorAction?
    @State private var isTextSelected: Bool = false
    
    // --- ESTADOS DE FEEDBACK ---
    @State private var invalidAttempts: Int = 0
    @State private var showSaveFeedback: Bool = false
    
    // --- CONFIGURACIÓN PERSISTENTE (ATAJOS) ---
    // Usamos valores por defecto seguros
    @AppStorage("shortcutNewNote") private var shortcutNewNote: String = "n"
    @AppStorage("shortcutList") private var shortcutList: String = "l"
    @AppStorage("shortcutSave") private var shortcutSave: String = "s"

    var body: some View {
        ZStack {
            // Fondo Global
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Cabecera
                headerView
                
                // Divisor con gradiente sutil
                Divider().overlay(
                    LinearGradient(colors: [.clear, .gray.opacity(0.4), .clear],
                                   startPoint: .leading,
                                   endPoint: .trailing)
                )
                
                // Área Principal
                ZStack {
                    if let note = selectedNote {
                        editorView(for: note)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .id(note.id) // Fuerza redibujado limpio al cambiar de nota
                    } else {
                        emptyStateView
                    }
                    
                    // Feedback de Guardado (Toast flotante)
                    if showSaveFeedback {
                        VStack {
                            Spacer()
                            Text("DATA SAVED")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                                .foregroundStyle(.white)
                                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5))
                                .padding(.bottom, 60)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .zIndex(100)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Barra de Estado Inferior
                statusBar
            }
            
            // Barra Flotante de Formato (Solo si hay selección de texto)
            if selectedNote != nil && isTextSelected {
                VStack {
                    Spacer()
                    floatingFormatBar
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        // Efecto de temblor en error
        .modifier(ShakeEffect(animatableData: CGFloat(invalidAttempts)))
        // Carga inicial
        .onAppear {
            if selectedNote == nil { selectedNote = notes.first }
        }
        // --- ATAJOS DE TECLADO INVISIBLES ---
        .background {
            // Es importante usar Character() para asegurar que el KeyEquivalent es válido
            Button("New") { checkAndCreateNote() }
                .keyboardShortcut(KeyEquivalent(shortcutNewNote.first ?? "n"), modifiers: .command)
            
            Button("List") { isShowingNoteList.toggle() }
                .keyboardShortcut(KeyEquivalent(shortcutList.first ?? "l"), modifiers: .command)
            
            Button("Save") { saveCurrentWork() }
                .keyboardShortcut(KeyEquivalent(shortcutSave.first ?? "s"), modifiers: .command)
        }
    }
    
    // MARK: - Componentes Visuales
    
    private var headerView: some View {
        HStack {
            AuraButton(icon: "line.3.horizontal", action: {
                isShowingNoteList.toggle()
            }, helpText: "Memory Bank (CMD+\(shortcutList.uppercased()))")
            .popover(isPresented: $isShowingNoteList, arrowEdge: .bottom) {
                noteListView
            }

            Spacer()
            
            Text("A U R A")
                .font(.system(.headline, design: .monospaced))
                .tracking(8)
                .foregroundStyle(LinearGradient(colors: [.white, .gray], startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(0.8)
            
            Spacer()
            
            HStack(spacing: 15) {
                AuraButton(icon: "gearshape", action: { isShowingSettings.toggle() }, helpText: "System Config")
                    .popover(isPresented: $isShowingSettings, arrowEdge: .bottom) {
                        AuraSettingsView(
                            newNoteKey: $shortcutNewNote,
                            listKey: $shortcutList,
                            saveKey: $shortcutSave
                        )
                    }
                
                AuraButton(icon: "plus", action: { checkAndCreateNote() }, helpText: "New Entity (CMD+\(shortcutNewNote.uppercased()))")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
    }
    
    private func editorView(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("UNTITLED", text: Bindable(note).title)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .textFieldStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.top, 30)
                .padding(.bottom, 10)
                // Dispara guardado al cambiar título
                .onChange(of: note.title) { _, _ in saveContext() }

            AuraEditor(text: Bindable(note).content, action: $editorAction, isTextSelected: $isTextSelected)
                .padding(.horizontal, 35)
                .padding(.bottom, 20)
        }
    }
    
    private var floatingFormatBar: some View {
        HStack(spacing: 15) {
            Group {
                formatButton(icon: "bold", action: .bold)
                formatButton(icon: "italic", action: .italic)
            }
            Divider().frame(height: 15).background(.gray)
            Group {
                formatButton(icon: "h.square", action: .heading(24))
                formatButton(icon: "textformat", action: .body)
            }
            Divider().frame(height: 15).background(.gray)
            Group {
                formatButton(icon: "list.bullet", action: .list)
                formatButton(icon: "tablecells", action: .table)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                .shadow(color: .white.opacity(0.1), radius: 10, x: 0, y: 5)
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        )
    }
    
    private func formatButton(icon: String, action: EditorAction) -> some View {
        Button(action: { editorAction = action }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
    
    private var statusBar: some View {
        HStack {
            if let note = selectedNote {
                Text("ID: \(note.timestamp.formatted(date: .omitted, time: .standard))")
                Spacer()
                Text("STATUS: ONLINE")
            } else {
                Text("STATUS: IDLE")
                Spacer()
            }
        }
        .font(.system(size: 9, design: .monospaced))
        .foregroundStyle(.gray.opacity(0.5))
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.black)
    }
    
    // MARK: - Menú de Lista
    private var noteListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MEMORY BANK")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.gray)
                .padding(12)
            
            Divider().background(.gray.opacity(0.3))
            
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(notes) { note in
                        Button(action: {
                            selectedNote = note
                            isShowingNoteList = false
                        }) {
                            HStack {
                                Circle()
                                    .fill(selectedNote == note ? Color.white : Color.clear)
                                    .frame(width: 6, height: 6)
                                Text(note.title.isEmpty ? "Untitled_Entity" : note.title)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(selectedNote == note ? .white : .gray)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle()) // Mejora el área de clic
                            .background(selectedNote == note ? Color.white.opacity(0.05) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete Entity", role: .destructive) {
                                deleteNote(note)
                            }
                        }
                    }
                }
                .padding(5)
            }
        }
        .frame(width: 260, height: 350)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "circle.dotted")
                .font(.system(size: 40))
                .foregroundStyle(.gray.opacity(0.2))
            Text("NO DATA SELECTED")
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.gray.opacity(0.4))
            Button("INITIALIZE NEW ENTRY") {
                checkAndCreateNote()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, design: .monospaced))
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 4).stroke(.gray.opacity(0.3)))
        }
    }

    // MARK: - Lógica de Negocio
    
    private func checkAndCreateNote() {
        // Evitar crear muchas notas vacías seguidas
        if let current = selectedNote, current.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            triggerErrorShake()
            return
        }
        
        withAnimation(.smooth) {
            let newNote = Note()
            modelContext.insert(newNote)
            selectedNote = newNote
        }
    }
    
    private func deleteNote(_ note: Note) {
        withAnimation {
            modelContext.delete(note)
            if selectedNote == note {
                selectedNote = nil
            }
        }
    }
    
    private func triggerErrorShake() {
        withAnimation(.default) { invalidAttempts += 1 }
        NSSound.beep()
    }
    
    private func saveCurrentWork() {
        saveContext()
        // Mostrar feedback visual
        withAnimation { showSaveFeedback = true }
        // Ocultar feedback después de 2 seg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSaveFeedback = false }
        }
    }
    
    private func saveContext() {
        try? modelContext.save()
    }
}

// MARK: - Subvista de Configuración Mejorada
struct AuraSettingsView: View {
    @Binding var newNoteKey: String
    @Binding var listKey: String
    @Binding var saveKey: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("SYSTEM CONFIG")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.gray)
                Spacer()
                Image(systemName: "command")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.5))
            }
            
            Divider().background(.gray.opacity(0.3))
            
            VStack(spacing: 12) {
                ShortcutInputRow(label: "NEW ENTRY", key: $newNoteKey)
                ShortcutInputRow(label: "OPEN LIST", key: $listKey)
                ShortcutInputRow(label: "SAVE DATA", key: $saveKey)
            }
            
            Divider().background(.gray.opacity(0.3))
            
            Text("CHANGES APPLY INSTANTLY")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.gray.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .frame(width: 240)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
    }
}

struct ShortcutInputRow: View {
    let label: String
    @Binding var key: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Text("CMD +")
                .font(.caption2)
                .monospaced()
                .foregroundStyle(.gray)
            
            Spacer()
            
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.gray.opacity(0.7))
            
            Spacer()
            
            TextField("", text: $key)
                .focused($isFocused)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(isFocused ? 0.2 : 0.1))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(isFocused ? 0.5 : 0), lineWidth: 1)
                )
                .onChange(of: key) { oldValue, newValue in
                    // Limitamos a 1 carácter
                    if newValue.count > 1 {
                        key = String(newValue.last!) // Mantiene el último carácter pulsado
                    }
                    // Asegurar que no esté vacío (volver al anterior o default)
                }
        }
    }
}
