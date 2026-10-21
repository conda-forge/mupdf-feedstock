// Exercise mutool's JavaScript engine and the MuPDF library: create a
// one-page PDF, save it, and read it back.
var doc = new PDFDocument();
doc.insertPage(-1, doc.addPage([0, 0, 200, 200], 0, {}, ""));
doc.save("mutool-test.pdf");
var n = new PDFDocument("mutool-test.pdf").countPages();
print("pages: " + n);
if (n !== 1)
	throw new Error("expected 1 page, got " + n);
