import tkinter as tk
from tkinter import filedialog
from tkinter import ttk
from ttkthemes import ThemedTk
import pdfplumber
import re
import datetime
import pyperclip


def estrai_dati(pdf_text):
    dati = {
        "Data Emissione": "",
        "Data Scadenza": "",
        "Numero Documento": "",
        "Fornitore": "",
        "Importo Imponibile": "",
        "IVA": "",
        "Descrizione": "",
        "Modalità di Pagamento": "",
        "Coordinate Bancarie": "",
        "Note": ""
    }

    lines = pdf_text.splitlines()
    full_text = pdf_text.lower()

    for line in lines:
        if "data emissione" in line.lower():
            dati["Data Emissione"] = line.split(":")[-1].strip()
        if "data scadenza" in line.lower():
            dati["Data Scadenza"] = line.split(":")[-1].strip()
        if "numero" in line.lower() and "documento" in line.lower():
            dati["Numero Documento"] = line.split(":")[-1].strip()
        if "fornitore" in line.lower():
            dati["Fornitore"] = line.split(":")[-1].strip()
        if "imponibile" in line.lower():
            dati["Importo Imponibile"] = re.findall(r"\d+[.,]\d+", line)[-1] if re.findall(r"\d+[.,]\d+", line) else ""
        if "iva" in line.lower():
            dati["IVA"] = re.findall(r"\d+[.,]\d+", line)[-1] if re.findall(r"\d+[.,]\d+", line) else ""
        if "modalità di pagamento" in line.lower():
            dati["Modalità di Pagamento"] = line.split(":")[-1].strip()
        if "coordinate bancarie" in line.lower():
            dati["Coordinate Bancarie"] = line.split(":")[-1].strip()

    if "utenza" in full_text:
        tipo = "utenza"
        desc_match = re.search(r"utenza.*?(energia|gas|acqua).*?(pod|pdr|codice utenza)[^\n]*", full_text)
        via_match = re.search(r"via [^\n,]+", full_text)
        descrizione = "Utenza " + (desc_match.group(0).strip() if desc_match else "")
        descrizione += " - " + (via_match.group(0).strip() if via_match else "")
        date_matches = re.findall(r"\d{2}/\d{2}/\d{4}", full_text)
        if date_matches:
            try:
                date_objs = [datetime.datetime.strptime(d, "%d/%m/%Y") for d in date_matches]
                dati["Note"] = f"Periodo: {min(date_objs).strftime('%d/%m/%Y')} - {max(date_objs).strftime('%d/%m/%Y')}"
            except:
                dati["Note"] = ""
        dati["Descrizione"] = descrizione
    else:
        tipo = "ordine"
        via_match = re.search(r"via [^\n,]+", full_text)
        dati["Descrizione"] = f"Riassunto fattura - {via_match.group(0).strip() if via_match else ''}"
        if "manutenzione straordinaria" in full_text:
            oda_match = re.search(r"oda[^\n]*", full_text)
            dati["Note"] = oda_match.group(0).strip() if oda_match else "ODA non trovata"
        else:
            date_matches = re.findall(r"\d{2}/\d{2}/\d{4}", full_text)
            if date_matches:
                try:
                    date_objs = [datetime.datetime.strptime(d, "%d/%m/%Y") for d in date_matches]
                    dati["Note"] = f"Periodo: {min(date_objs).strftime('%d/%m/%Y')} - {max(date_objs).strftime('%d/%m/%Y')}"
                except:
                    dati["Note"] = ""

    return dati


def carica_pdf():
    file_path = filedialog.askopenfilename(filetypes=[("PDF files", "*.pdf")])
    if not file_path:
        return

    with pdfplumber.open(file_path) as pdf:
        testo = "\n".join(page.extract_text() for page in pdf.pages if page.extract_text())

    dati = estrai_dati(testo)
    for campo, valore in dati.items():
        v = entries[campo]
        v["var"].set(valore)


def crea_interfaccia():
    root = ThemedTk(theme="black")
    root.title("Estrazione Fattura PDF")
    root.geometry("700x600")

    frame = ttk.Frame(root, padding=10)
    frame.pack(fill=tk.BOTH, expand=True)

    global entries
    entries = {}

    for i, campo in enumerate([
        "Data Emissione", "Data Scadenza", "Numero Documento", "Fornitore",
        "Importo Imponibile", "IVA", "Descrizione", "Modalità di Pagamento",
        "Coordinate Bancarie", "Note"]):

        label = ttk.Label(frame, text=campo + ":", anchor="w")
        label.grid(row=i, column=0, sticky="w")

        var = tk.StringVar()
        entry = ttk.Entry(frame, textvariable=var, width=80)
        entry.grid(row=i, column=1, padx=5, pady=5, sticky="w")

        copy_btn = ttk.Button(frame, text="📋", width=3, command=lambda v=var: pyperclip.copy(v.get()))
        copy_btn.grid(row=i, column=2, padx=2, pady=5)

        entries[campo] = {"entry": entry, "var": var}

    carica_btn = ttk.Button(frame, text="Seleziona PDF", command=carica_pdf)
    carica_btn.grid(row=len(entries), column=1, pady=20)

    root.mainloop()


if __name__ == "__main__":
    crea_interfaccia()
