# Znuny – Beschaffungsprozess Konfigurationsdateien

## Übersicht

Dieser Ordner enthält alle Konfigurationsdateien für einen vollständigen
elektronischen Beschaffungsprozess (Purchase-to-Pay) in Znuny/OTRS.

---

## Prozessschritte

```
[1]  BANF erstellen       →  Dialog: Formular ausfüllen (Kostenstelle, Menge, Wert…)
[2]  BANF senden          →  Transition prüft Pflichtfelder
[3]  BANF freigeben       →  Genehmiger wählt "freigegeben" oder "abgelehnt"
[4]  Bestellung versenden →  PO-Nummer & Liefertermin erfassen
[5]  Lieferung erhalten   →  Lieferschein & Eingangsdatum erfassen
[6]  Rechnung erhalten    →  Rechnungsdaten erfassen
[7]  Rechnung kontieren   →  Sachkonto, Kostenstelle zuweisen
[8]  Rechnung freigeben   →  Sachliche und rechnerische Prüfung
[9]  Zahlanweisung        →  Abschluss, Status = "Rechnung-versendet" (closed)
```

Zusätzliche Pfade:
- BANF kann **abgelehnt** werden → Endstatus "BANF-abgelehnt"
- Rechnung kann **abgelehnt** werden → Rückschleife zur Klärung

---

## Dateien

| Datei | Inhalt |
|-------|--------|
| `Config/Queues.xml` | 5 Sub-Queues unter `Beschaffung::*` |
| `Config/TicketStates.xml` | 11 Prozess-Status (9 Hauptschritte + 2 Ablehnungen) |
| `Config/DynamicFields.xml` | 20 Dynamic Fields (Gruppen A–E) |
| `ProcessManagement/BeschaffungsProzess.pm` | Prozess, Activities, Dialogs, Transitions |

---

## Importreihenfolge (wichtig!)

Die Dateien **müssen in dieser Reihenfolge** eingespielt werden:

### Schritt 1 – Ticket States

**Admin → Ticket States → Add State**  
Oder XML-Import über System Configuration:

```bash
bin/znuny.Console.pl Maint::Config::Rebuild
```

Aus `Config/TicketStates.xml` die States anlegen:
- BANF-Entwurf (open)
- BANF-gesendet (pending reminder)
- BANF-freigegeben (open)
- BANF-abgelehnt (closed unsuccessful)
- Bestellung-versendet (pending reminder)
- Lieferung-erhalten (open)
- Rechnung-erhalten (open)
- Rechnung-kontiert (open)
- Rechnung-freigegeben (open)
- Rechnung-abgelehnt (open)
- Rechnung-versendet (closed successful)

### Schritt 2 – Queues

**Admin → Queues → Add Queue**

Anlegen in dieser Reihenfolge (Eltern zuerst):
1. `Beschaffung`
2. `Beschaffung::BANF`
3. `Beschaffung::Genehmigung`
4. `Beschaffung::Bestellung`
5. `Beschaffung::Wareneingang`
6. `Beschaffung::Rechnungsprüfung`

### Schritt 3 – Dynamic Fields

**Admin → Dynamic Fields → Add Field**

Alle Felder aus `Config/DynamicFields.xml` anlegen (Typ jeweils beachten):

| Feldname | Typ |
|----------|-----|
| BeschaffungKostenstelle | Text |
| BeschaffungKostentraeger | Text |
| BeschaffungPositionsbeschreibung | TextArea |
| BeschaffungMenge | Text |
| BeschaffungEinheit | Dropdown |
| BeschaffungGeschaetzterWert | Text |
| BeschaffungLieferant | Text |
| BeschaffungBedarfstermin | Date |
| BeschaffungGenehmigungsDatum | DateTime |
| BeschaffungGenehmigungskommentar | TextArea |
| BeschaffungBestellnummer | Text |
| BeschaffungLieferterminBestaetigt | Date |
| BeschaffungLieferscheinNummer | Text |
| BeschaffungWareneingangsDatum | Date |
| BeschaffungWareneingangsMangel | TextArea |
| BeschaffungRechnungsnummer | Text |
| BeschaffungRechnungsdatum | Date |
| BeschaffungRechnungsBetragBrutto | Text |
| BeschaffungSachkonto | Text |
| BeschaffungZahlungsziel | Dropdown |

### Schritt 4 – Prozess importieren

**Admin → Process Management → Import Process**

Datei: `ProcessManagement/BeschaffungsProzess.pm`

Nach dem Import:
1. Prozess auf **Active** setzen
2. **"Synchronize all Processes"** klicken (oben rechts)

---

## Berechtigungskonzept (Empfehlung)

| Gruppe | Queue | Rolle |
|--------|-------|-------|
| Einkauf-Mitarbeiter | Beschaffung::BANF | rw |
| Vorgesetzte | Beschaffung::Genehmigung | rw |
| Einkauf-Sachbearbeiter | Beschaffung::Bestellung | rw |
| Lager / Wareneingang | Beschaffung::Wareneingang | rw |
| Buchhaltung | Beschaffung::Rechnungsprüfung | rw |
| Controlling / Freigabe | Beschaffung::Rechnungsprüfung | rw |

---

## Hinweise

- Alle Ticket-States mit `StateType = "pending reminder"` lösen nach
  konfigurierbarem Zeitraum automatisch eine Erinnerungsmail aus.
- Die Transition-Bedingungen prüfen über RegEx `.+` ob Pflichtfelder
  befüllt sind. Feinere Validierungen (z.B. nur Zahlen, Datumsformate)
  können in den DynamicField-Definitionen per `RegExList` ergänzt werden.
- Für eine SAP-Integration können die Felder `BeschaffungBestellnummer`
  und `BeschaffungRechnungsnummer` als Schlüssel für einen Znuny GenericAgent
  oder eine REST-API-Anbindung genutzt werden.
