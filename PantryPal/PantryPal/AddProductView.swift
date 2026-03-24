import SwiftUI
import PhotosUI
import VisionKit

// MARK: - AddProductView

struct AddProductView: View {
    @EnvironmentObject var store: ProductStore
    @State private var notificationManager = NotificationManager()
    @Environment(\.dismiss) var dismiss

    @Binding var isPresented: Bool
    var editingProduct: Product? = nil

    @State private var name:          String = ""
    @State private var brand:         String = ""
    @State private var selectedCatID: UUID?  = nil
    @State private var expiryDate:    Date   = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var notes:         String = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var imageData:     Data?  = nil

    @State private var activeScanMode: ScanMode? = nil

    var isEditing: Bool { editingProduct != nil }
    var title: String   { isEditing ? "Edit Product" : "Add Product" }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Photo
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Group {
                                if let data = imageData, let img = UIImage(data: data) {
                                    Image(uiImage: img).resizable().scaledToFill()
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: "camera.fill")
                                            .font(.largeTitle)
                                            .foregroundStyle(.teal)
                                        Text("Add Photo").font(.caption).foregroundStyle(.teal)
                                    }
                                }
                            }
                            .frame(width: 120, height: 120)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                            .clipped()
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task { imageData = try? await item?.loadTransferable(type: Data.self) }
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                // MARK: Product Name
                Section {
                    HStack {
                        TextField("Name *", text: $name)
                        if !isEditing {
                            Button { activeScanMode = .productName } label: {
                                Image(systemName: "text.viewfinder")
                                    .foregroundStyle(.teal)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    TextField("Brand", text: $brand)
                } header: {
                    Text("Product Name")
                } footer: {
                    if !isEditing {
                        Text("Tap the scan icon to scan the name off the packaging")
                            .font(.caption2)
                    }
                }

                // MARK: Expiry Date
                Section("Expiry / Best By Date") {
                    if !isEditing {
                        Button { activeScanMode = .expiryDate } label: {
                            Label("Scan Date from Package", systemImage: "calendar.badge.clock")
                                .foregroundStyle(.teal)
                        }
                    }
                    DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(.teal)
                }

                // MARK: Category
                Section("Category") {
                    Picker("Category", selection: $selectedCatID) {
                        Text("Select…").tag(Optional<UUID>.none)
                        ForEach(store.categories) { cat in
                            Label(cat.name, systemImage: cat.icon).tag(Optional(cat.id))
                        }
                    }
                }

                // MARK: Notes
                Section("Notes") {
                    TextField("Optional notes…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .bold()
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { prefill() }
            .sheet(item: $activeScanMode) { mode in
                FieldScannerSheet(mode: mode) { result in
                    apply(result)
                }
            }
        }
    }

    // MARK: - Apply Scan Result

    private func apply(_ result: ScanFieldResult) {
        switch result {
        case .name(let text):
            name = text
        case .date(let date):
            expiryDate = date
        }
    }

    // MARK: - Prefill (editing only)

    private func prefill() {
        selectedCatID = store.categories.first?.id
        guard let p = editingProduct else { return }
        name          = p.name
        brand         = p.brand
        selectedCatID = p.categoryID
        expiryDate    = p.expiryDate
        notes         = p.notes
        imageData     = p.imageData
    }

    // MARK: - Save

    private func save() {
        guard let catID = selectedCatID ?? store.categories.first?.id else { return }

        if let existing = editingProduct {
            var updated        = existing
            updated.name       = name.trimmingCharacters(in: .whitespaces)
            updated.brand      = brand.trimmingCharacters(in: .whitespaces)
            updated.categoryID = catID
            updated.expiryDate = expiryDate
            updated.notes      = notes
            updated.imageData  = imageData
            store.updateProduct(updated)
            notificationManager.scheduleExpiryNotification(for: updated)
        } else {
            let product = Product(
                name:       name.trimmingCharacters(in: .whitespaces),
                brand:      brand.trimmingCharacters(in: .whitespaces),
                categoryID: catID,
                expiryDate: expiryDate,
                notes:      notes
            )
            store.addProduct(product)
            notificationManager.scheduleExpiryNotification(for: product)
        }
        isPresented = false
    }
}
