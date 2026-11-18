# Disclaimer

## Not affiliated with PETKIT

OpenMusca is an independent, unofficial community project. It is **not affiliated with, authorised, sponsored or
endorsed by PETKIT** or any of its partners. "PETKIT" and "YumShare" are trademarks of their respective owners and are
used here only to name the hardware this project is compatible with.

## Use at your own risk

OpenMusca is experimental software for a device that feeds animals. Installing it is **entirely at your own risk**:

- It can make the device unusable ("brick" it) or behave unexpectedly, including feeding too much, too little or not at
  all. Always keep the feeder's own schedule or another way to feed your pet, and check on your animal.
- Opening or modifying the device may affect warranty or guarantee claims against the seller or manufacturer.
- The software is provided "as is", without warranty of any kind (see the [MIT licence](licensing.md)). The authors are
  not liable for damage to devices, data, animals or anything else, as far as the law permits.
- You are responsible for operating the device lawfully, including its radio (Wi-Fi). OpenMusca uses the radio driver
  with its normal settings and does not intend to change regulatory parameters such as country code or transmit power.

## Legal background (Germany / EU)

*This section is general information, not legal advice. Laws differ between countries; if in doubt, ask a lawyer.*

Our understanding of why an owner may modify their own device under German and EU law:

- **Ownership:** the owner of a thing may deal with it as they wish, unless the law or rights of third parties stand
  in the way (§ 903 BGB). Note that this right belongs to the owner (*Eigentümer*); a borrower or tenant
  (*Besitzer* only) may need the owner's consent.
- **Software on the device:** a lawful user may carry out the acts needed to use a program as intended, including
  correcting errors (§ 69d Abs. 1 UrhG), and may observe, study and test how it works in order to understand the ideas
  and principles behind it (§ 69d Abs. 3 UrhG).
- **Interoperability:** decompiling parts of a program is allowed when it is indispensable to make an independently
  created program work with it, limited to what is necessary and under the conditions of § 69e UrhG. These rules
  implement Articles 5 and 6 of Directive 2009/24/EC.
- **Trade secrets:** observing, studying, taking apart or testing a product that was made publicly available or that
  is lawfully in one's possession is a permitted way to obtain information (§ 3 Abs. 1 Nr. 2 GeschGehG), unless a
  valid contract says otherwise.

How OpenMusca stays within these limits:

- **No vendor code or firmware is distributed.** The project publishes only its own code and its own documentation.
- **Clean room:** hardware facts needed for interoperability are written down as specifications; our own code is
  written from those specifications, not copied from vendor material.
- **Your device, your files:** anything device-specific that cannot be replaced (for example radio firmware) is
  taken from your own device during installation and never leaves it.

## How this project is made (AI assistance)

OpenMusca is developed by a human maintainer with the help of AI coding assistants. We say this openly:

- **What AI does here:** large parts of the code, tests, analyses and documentation were drafted by AI assistants
  under the maintainer's direction. The maintainer decides what is built, reviews the results, runs every test on
  real hardware and is responsible for what is published.
- **Clean room with AI:** vendor material is never copied. An *analyst* session reads vendor material and writes
  only hardware facts (registers, bits, timings, binding names) into a specification. A separate *implementer*
  session, without access to vendor material or the analyst's context, writes our code from that specification.
  Each step records which files were read (`PROVENANCE.md`), and similarity checks compare our code with the
  vendor code. Limitation: both roles are AI sessions of the same model; whether that counts as two separate people
  in the legal sense is an open question we will have checked.
- **Quality gates:** every change goes through automated tests (unit, end-to-end against a simulated MCU, fuzzing,
  reproducible builds, licence and secret scans) and an independent review step before it touches a device.
- **Licence:** the MIT licence applies to this work as far as rights exist in it. Under German and EU law, copyright
  requires a human's own intellectual creation (§ 2 Abs. 2 UrhG); the maintainer's selection, direction and review
  are that human part.
- **Regulation:** we understand the transparency duties of the EU AI Act (Art. 50) as not applying to source code and
  technical documentation of this kind; we disclose AI use voluntarily. This is not legal advice.
- **Upstream contributions:** patches sent to other projects (for example the Linux kernel) follow those projects'
  rules for AI-assisted contributions and are signed off (DCO) by a human.

## Haftungsausschluss (Kurzfassung auf Deutsch)

OpenMusca ist ein unabhängiges Community-Projekt und steht in **keiner Verbindung zu PETKIT**; es wird von PETKIT
weder unterstützt noch empfohlen. Die Nutzung erfolgt **auf eigene Gefahr**: Das Gerät kann unbrauchbar werden oder
falsch füttern, Garantie- oder Gewährleistungsansprüche können betroffen sein, und es gibt keine Gewähr. Als
Eigentümer darfst du mit deinem Gerät grundsätzlich nach Belieben verfahren (§ 903 BGB); für die Software auf dem
Gerät gelten insbesondere §§ 69d und 69e UrhG sowie § 3 Abs. 1 Nr. 2 GeschGehG. Dies ist keine Rechtsberatung. OpenMusca wird mit Hilfe von KI-Assistenten entwickelt; Prüfung, Tests auf echter Hardware und
Verantwortung liegen beim Maintainer (Details oben).
