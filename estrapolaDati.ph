import pdfplumber
import tkinter as tk
from tkinter import filedialog, messagebox
from ttkthemes import ThemedTk
from tkinter import ttk
import re
from datetime import datetime

# --- Estrazione dati da PDF ---
def estrai_dati_da_pdf(percorso_pdf):
    with pdfplumber.open(percorso_pdf) as pdf:
        testo = "\n".join(page.extract_text() for page in pdf.pages if page.extract_text())

    dati = {
        "Data Emissione": cerca_data(testo, r"Data.?Emissione.*?(\d{2}/\d{2}/\d{4})"),
        "Data Scadenza": cerca_data(testo, r"Data.?Scadenza.*?(\d{2}/\d{2}/\d{4})"),
        "Numero Documento": cerca_valore(testo, r"N[.o]? Documento\s*[:\-]?\s*(\S+)", default="Non trovato"),
        "Fornitore": cerca_valore(testo, r"Fornitore[:\-]?\s*(.+?)\n", default="Non trovato"),
        "Importo Imponibile": cerca_valore(testo, r"Imponibile[:\-]?\s*([0-9.,]+)", default="0"),
        "IVA": cerca_valore(testo, r"IVA[:\-]?\s*([0-9.,]+)%?", default="0"),
        "Modalità di Pagamento": cerca_valore(testo, r"Pagamento[:\-]?\s*(.+?)\n", default="Non trovato"),
        "Coordinate Bancarie": cerca_valore(testo, r"(IBAN\s*[:\-]?[A-Z0-9 ]{10,})", default="Non trovato"),
    }

    tipo = "utenza" if re.search(r"(POD|PDR|utenza|energia|acqua|gas)", testo, re.I) else "ordine"

    if tipo == "utenza":
        dati["Descrizione"] = descrizione_utenza(testo)
        dati["Note"] = periodo_riferimento(testo)
    else:
        dati["Descrizione"] = descrizione_ordine(testo)
        dati["Note"] = nota_ordine(testo)

    return dati

# --- Funzioni di supporto ---
def cerca_valore(testo, pattern, default=""):
    match = re.search(pattern, testo, re.IGNORECASE)
    return match.group(1).strip() if match else default

def cerca_data(testo, pattern):
    val = cerca_valore(testo, pattern)
    try:
        return datetime.strptime(val, "%d/%m/%Y").strftime("%Y-%m-%d")
    except:
        return val

def descrizione_utenza(testo):
    tipo = re.search(r"(acqua|gas|energia)", testo, re.I)
    codice = re.search(r"(POD|PDR|Codice Utenza)[:\s]*([A-Z0-9]+)", testo, re.I)
    via = re.search(r"via\s+[\w\s,.]+", testo, re.I)
    return f"Utenza {tipo.group(1).capitalize()} - {codice.group(1)}: {codice.group(2)} - {via.group(0).strip()}" if tipo and codice and via else "Descrizione utenza non trovata"

def descrizione_ordine(testo):
    via = re.search(r"via\s+[\w\s,.]+", testo, re.I)
    return f"Manutenzione - {via.group(0).strip()}" if via else "Descrizione ordine non trovata"

def nota_ordine(testo):
    if "manutenzione straordinaria" in testo.lower():
        oda = re.search(r"ODA\s*\d+", testo, re.I)
        return oda.group(0) if oda else "ODA non trovata"
    else:
        return periodo_riferimento(testo)

def periodo_riferimento(testo):
    date_matches = re.findall(r"\d{2}/\d{2}/\d{4}", testo)
    date_objs = [datetime.strptime(d, "%d/%m/%Y") for d in date_matches]
    if date_objs:
        return f"Periodo: {min(date_objs).strftime('%d/%m/%Y')} - {max(date_objs).strftime('%d/%m/%Y')}"
    return "Periodo non trovato"

# --- GUI ---
def apri_file():
    file_path = filedialog.askopenfilename(filetypes=[("PDF files", "*.pdf")])
    if not file_path:
        return
    try:
        dati = estrai_dati_da_pdf(file_path)
        for chiave in campi:
            campi[chiave].delete(0, tk.END)
            campi[chiave].insert(0, dati.get(chiave, ""))
        descrizione_text.delete("1.0", tk.END)
        descrizione_text.insert("1.0", dati.get("Descrizione", ""))
        note_text.delete("1.0", tk.END)
        note_text.insert("1.0", dati.get("Note", ""))
    except Exception as e:
        messagebox.showerror("Errore", str(e))

# --- Setup interfaccia dark ---
root = ThemedTk(theme="equilux")
root.title("Fattura Extractor")
root.geometry("700x600")

frame = ttk.Frame(root, padding=10)
frame.pack(fill="both", expand=True)

tt_btn = ttk.Button(frame, text="Seleziona PDF", command=apri_file)
tt_btn.pack(pady=10)

campi = {}
for nome in ["Data Emissione", "Data Scadenza", "Numero Documento", "Fornitore",
             "Importo Imponibile", "IVA", "Modalità di Pagamento", "Coordinate Bancarie"]:
    lbl = ttk.Label(frame, text=nome)
    lbl.pack(anchor="w")
    entry = ttk.Entry(frame, width=80)
    entry.pack(fill="x", pady=2)
    campi[nome] = entry

# Descrizione
ttk.Label(frame, text="Descrizione").pack(anchor="w")
descrizione_text = tk.Text(frame, height=3, bg="#2e2e2e", fg="white")
descrizione_text.pack(fill="x", pady=5)

# Note
ttk.Label(frame, text="Note").pack(anchor="w")
note_text = tk.Text(frame, height=3, bg="#2e2e2e", fg="white")
note_text.pack(fill="x", pady=5)

root.mainloop()
