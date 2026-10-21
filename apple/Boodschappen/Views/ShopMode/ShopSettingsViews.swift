#if os(iOS)
import SwiftUI

/// De zinnen per stap van de winkelmodus aanpassen.
struct ShopMessagesEditor: View {
    var isSheet = false

    @Environment(\.dismiss) private var dismiss
    @State private var step: ShopStep
    @State private var store = ShopMessageStore.shared
    @State private var confirmingReset = false

    init(initialStep: ShopStep = .help, isSheet: Bool = false) {
        _step = State(initialValue: initialStep)
        self.isSheet = isSheet
    }

    private var messages: Binding<[ShopMessage]> {
        Binding(
            get: { store.messages(for: step) },
            set: { newValue in store.update(step) { $0 = newValue } }
        )
    }

    var body: some View {
        List {
            Section {
                Picker("Stap", selection: $step) {
                    ForEach(ShopStep.allCases) { step in
                        Text(step.title).tag(step)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                ForEach(messages) { $message in
                    TextField("Bericht", text: $message.text, axis: .vertical)
                }
                .onDelete { offsets in
                    store.update(step) { $0.remove(atOffsets: offsets) }
                }
                .onMove { source, destination in
                    store.update(step) { $0.move(fromOffsets: source, toOffset: destination) }
                }
                Button {
                    store.update(step) { $0.append(ShopMessage(text: "")) }
                } label: {
                    Label("Bericht toevoegen", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Berichten bij \(step.title.lowercased())")
            } footer: {
                Text("In de winkelmodus tik je op een bericht: het komt groot in beeld en wordt voorgelezen. Veeg naar links om te verwijderen.")
            }

            Section {
                Button("Standaardberichten terugzetten", role: .destructive) {
                    confirmingReset = true
                }
            }
        }
        .navigationTitle("Berichten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .confirmationDialog("Standaardberichten bij \(step.title.lowercased()) terugzetten?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Terugzetten", role: .destructive) {
                store.resetToDefaults(for: step)
            }
        }
    }
}

/// Betaalkaarten beheren; alleen na Face ID.
struct PaymentCardsView: View {
    var isSheet = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = PaymentCardStore.shared
    @State private var isUnlocked = false
    @State private var editingCard: PaymentCard?

    var body: some View {
        Group {
            if isUnlocked {
                cardList
            } else {
                ContentUnavailableView {
                    Label("Vergrendeld", systemImage: "lock.fill")
                } description: {
                    Text("Ontgrendel met Face ID om je betaalkaarten te zien.")
                } actions: {
                    Button("Ontgrendel") {
                        Task { await unlock() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Betaalkaarten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
        .task {
            store.loadIfNeeded()
            await unlock()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                isUnlocked = false
                editingCard = nil
            }
        }
        .sheet(item: $editingCard) { card in
            NavigationStack {
                PaymentCardEditor(card: card, isNew: !store.cards.contains { $0.id == card.id })
            }
        }
    }

    private var cardList: some View {
        List {
            Section {
                ForEach(store.cards) { card in
                    Button {
                        editingCard = card
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(card.name)
                                .font(.headline)
                            if !card.sentence.isEmpty {
                                Text(card.sentence)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Pincode: " + String(repeating: "•", count: card.pin.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { store.delete(atOffsets: $0) }
                .onMove { store.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    editingCard = PaymentCard(name: "", sentence: "", pin: "")
                } label: {
                    Label("Betaalkaart toevoegen", systemImage: "plus.circle.fill")
                }
            } footer: {
                Text("Pincodes staan alleen op deze iPhone, in de beveiligde sleutelhanger van iOS, en gaan niet mee met iCloud. In de winkelmodus verschijnt een pincode pas na Face ID, en maar 10 seconden.")
            }
        }
    }

    private func unlock() async {
        isUnlocked = await OwnerAuthentication.confirm(reason: "Om je betaalkaarten te beheren")
    }
}

struct PaymentCardEditor: View {
    let isNew: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var card: PaymentCard
    @State private var showsPIN = false
    @State private var confirmingDelete = false
    @State private var saveFailed = false

    init(card: PaymentCard, isNew: Bool) {
        _card = State(initialValue: card)
        self.isNew = isNew
    }

    private var isValid: Bool {
        !card.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && PaymentCard.isValidPIN(card.pin)
    }

    var body: some View {
        Form {
            Section("Naam") {
                TextField("Bijvoorbeeld ASN of Revolut", text: $card.name)
            }
            Section {
                TextField("Bijvoorbeeld: Ik kan pinnen met de gele chip die aan mijn rolstoel hangt.", text: $card.sentence, axis: .vertical)
            } header: {
                Text("Wat de app zegt")
            } footer: {
                Text("Deze zin wordt groot getoond en voorgelezen als je in de winkelmodus deze kaart kiest.")
            }
            Section {
                HStack {
                    Group {
                        if showsPIN {
                            TextField("Pincode", text: $card.pin)
                        } else {
                            SecureField("Pincode", text: $card.pin)
                        }
                    }
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                    Button {
                        showsPIN.toggle()
                    } label: {
                        Image(systemName: showsPIN ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(showsPIN ? "Verberg pincode" : "Toon pincode")
                }
            } header: {
                Text("Pincode")
            } footer: {
                Text("Alleen cijfers, 4 tot 12.")
            }
            if !isNew {
                Section {
                    Button("Verwijder kaart", role: .destructive) {
                        confirmingDelete = true
                    }
                }
            }
        }
        .onChange(of: card.pin) { _, newValue in
            let digits = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(12))
            if digits != newValue { card.pin = digits }
        }
        .navigationTitle(isNew ? "Nieuwe kaart" : "Kaart wijzigen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuleer") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Bewaar") {
                    card.name = card.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    card.sentence = card.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    if PaymentCardStore.shared.save(card) {
                        dismiss()
                    } else {
                        saveFailed = true
                    }
                }
                .disabled(!isValid)
            }
        }
        .alert("Kaart niet bewaard", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("De beveiligde sleutelhanger van de iPhone kon de kaart nu niet opslaan. Ontgrendel je iPhone en probeer het opnieuw.")
        }
        .confirmationDialog("Kaart verwijderen?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Verwijder", role: .destructive) {
                PaymentCardStore.shared.delete(card)
                dismiss()
            }
        }
    }
}
#endif
