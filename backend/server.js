require("dotenv").config();
const mongoose = require("mongoose");
const express = require("express");
const multer = require("multer");
const pdfParse = require("pdf-parse");
const { Document, Packer, Paragraph } = require("docx");
const cors = require("cors");
const { PDFDocument, rgb, StandardFonts, degrees } = require("pdf-lib");
const fs = require("fs");
const path = require("path");

const Tesseract = require("tesseract.js");
const { execFile } = require("child_process");
const { promisify } = require("util");
const execFileAsync = promisify(execFile);
const libre = require("libreoffice-convert");
const PDFDocument = require("pdfkit");
const sharp = require("sharp");
const PptxGenJS = require("pptxgenjs");
const XLSX = require("xlsx");
const archiver = require("archiver");
const AdmZip = require("adm-zip");
const app = express();
async function convertPdfToImages(pdfPath, outputDir, prefix, format = "png", resolution = 120) {
  const outputPrefix = path.join(outputDir, prefix);

  await execFileAsync("pdftoppm", [
    "-r",
    String(resolution),
    format === "jpeg" ? "-jpeg" : "-png",
    pdfPath,
    outputPrefix,
  ]);
}

app.use(cors());
app.use(express.json());
app.use("/uploads", express.static("uploads"));
mongoose
  .connect(process.env.MONGO_URL)
  .then(() => console.log("MongoDB connected"))
  .catch((err) => console.log("MongoDB error:", err));

const PdfSchema = new mongoose.Schema({
  title: String,
  category: String,
  description: String,
  fileName: String,
  filePath: String,
  fileUrl: String,
 ownerId: String,
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

const Pdf = mongoose.model("Pdf", PdfSchema);

const uploadPath = path.join(__dirname, "uploads");

if (!fs.existsSync(uploadPath)) {
  fs.mkdirSync(uploadPath, { recursive: true });
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadPath);
  },

  filename: function (req, file, cb) {
    cb(null, Date.now() + "-" + file.originalname);
  },
});

const upload = multer({ storage });

app.get("/", (req, res) => {
  res.send("PDF Backend Running");
});

// ✅ Get all PDFs
app.get("/api/pdfs", async (req, res) => {
  try {
    const pdfs = await Pdf.find().sort({ createdAt: -1 });
    res.json(pdfs);
  } catch (error) {
    res.status(500).json({ error: "PDF fetch failed" });
  }
});

// ✅ Get PDFs by ownerId
app.get("/api/pdfs/:ownerId", async (req, res) => {
  try {
    const pdfs = await Pdf.find({ ownerId: req.params.ownerId }).sort({
      createdAt: -1,
    });
    res.json(pdfs);
  } catch (error) {
    res.status(500).json({ error: "PDF fetch failed" });
  }
});

// ✅ Save PDF data
app.post("/api/pdfs", async (req, res) => {
  try {
    const pdf = await Pdf.create(req.body);
    res.json(pdf);
  } catch (error) {
    res.status(500).json({ error: "PDF save failed" });
  }
});
app.post("/api/upload-pdf", upload.single("pdf"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "PDF file required" });
    }

    const pdf = await Pdf.create({
      title: req.body.title,
      category: req.body.category,
      description: req.body.description,
      ownerId: req.body.ownerId,
      fileName: req.file.originalname,
      filePath: req.file.path,
      fileUrl: `${process.env.BASE_URL}/uploads/${req.file.filename}`,
    });

    res.json(pdf);
  } catch (error) {
    res.status(500).json({ error: "PDF upload failed" });
  }
});

app.delete("/api/pdfs/:id", async (req, res) => {
  try {
    const deletedPdf = await Pdf.findByIdAndDelete(req.params.id);

    if (!deletedPdf) {
      return res.status(404).json({ error: "PDF not found" });
    }

    res.json({ message: "PDF deleted successfully" });
  } catch (error) {
    res.status(500).json({ error: "PDF delete failed" });
  }
});

// ✅ Convert PDF to Word
app.post("/convert-pdf-to-word", upload.single("pdf"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "PDF file required" });
    }

    let finalText = "";

    try {
      const data = await pdfParse(fs.readFileSync(req.file.path));
      finalText = data.text || "";
    } catch (e) {
      console.log("PDF text parse failed:", e.message);
    }

    if (!finalText.trim()) {
      const outputDir = path.join(__dirname, "ocr_output");

      if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
      }

      const prefix = path.parse(req.file.filename).name;

     await convertPdfToImages(
       req.file.path,
       outputDir,
       prefix,
       "png",
       100
     );

      const imageFiles = fs
        .readdirSync(outputDir)
        .filter((file) => file.startsWith(prefix) && file.endsWith(".png"));

      for (const imageFile of imageFiles) {
        const imagePath = path.join(outputDir, imageFile);
        const optimizedImage = imagePath.replace(".png", "-optimized.png");

        await sharp(imagePath)
          .grayscale()
          .normalize()
           .resize({ width: 1000, withoutEnlargement: true })
          .sharpen()
          .toFile(optimizedImage);

        const result = await Tesseract.recognize(optimizedImage, "eng");
        finalText += "\n" + result.data.text;
      }
    }

    if (!finalText.trim()) {
      return res.status(400).json({
        error: "No readable text found in this PDF",
      });
    }

    const paragraphs = finalText
      .split("\n")
      .filter((line) => line.trim() !== "")
      .map((line) => new Paragraph(line.trim()));

    const doc = new Document({
      sections: [{ children: paragraphs }],
    });

    const buffer = await Packer.toBuffer(doc);

    res.setHeader(
      "Content-Type",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    );
    res.setHeader(
      "Content-Disposition",
      'attachment; filename="converted.docx"'
    );

    res.send(buffer);
  } catch (error) {
    console.error("PDF TO WORD ERROR:", error);
    res.status(500).json({ error: "PDF to Word conversion failed" });
  }
});
app.post("/convert-office-to-pdf", upload.single("file"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "File required" });
    }

    const inputBuffer = fs.readFileSync(req.file.path);

    libre.convert(inputBuffer, ".pdf", undefined, (err, pdfBuffer) => {
      if (err) {
        console.error("Office convert error:", err);
        return res.status(500).json({ error: "Office to PDF conversion failed" });
      }

      res.setHeader("Content-Type", "application/pdf");
      res.setHeader("Content-Disposition", 'attachment; filename="converted.pdf"');
      res.send(pdfBuffer);
    });
  } catch (error) {
    console.error("Convert route error:", error);
    res.status(500).json({ error: "Conversion failed" });
  }
});
app.post("/image-to-pdf", upload.array("images"), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: "Images required" });
    }

    const doc = new PDFDocument({
      autoFirstPage: false,
    });

    const chunks = [];

    doc.on("data", (chunk) => chunks.push(chunk));

    doc.on("end", () => {
      const pdfBuffer = Buffer.concat(chunks);

      res.setHeader("Content-Type", "application/pdf");
      res.setHeader(
        "Content-Disposition",
        'attachment; filename="images.pdf"'
      );

      res.send(pdfBuffer);
    });

    for (const file of req.files) {
      doc.addPage({
        size: "A4",
        margin: 20,
      });

      doc.image(file.path, 20, 20, {
        fit: [555, 800],
        align: "center",
        valign: "center",
      });
    }

    doc.end();
  } catch (error) {
    console.error("IMAGE TO PDF ERROR:", error);
    res.status(500).json({ error: "Image to PDF failed" });
  }
});
app.post("/pdf-to-jpg", upload.single("pdf"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "PDF required" });

    const outputDir = path.join(__dirname, "pdf_jpg_output");
    if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

    const prefix = path.parse(req.file.filename).name;

   await convertPdfToImages(
     req.file.path,
     outputDir,
     prefix,
     "jpeg",
     120
   );

    res.setHeader("Content-Type", "application/zip");
    res.setHeader("Content-Disposition", 'attachment; filename="pdf_images.zip"');

  const AdmZip = require("adm-zip");

  const zip = new AdmZip();

  fs.readdirSync(outputDir)
    .filter((f) => f.startsWith(prefix) && f.endsWith(".jpg"))
    .forEach((file) => {
      zip.addLocalFile(path.join(outputDir, file));
    });

  const zipBuffer = zip.toBuffer();

  res.setHeader("Content-Type", "application/zip");
  res.setHeader(
    "Content-Disposition",
    'attachment; filename="pdf_images.zip"'
  );

  res.send(zipBuffer);
  
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "PDF to JPG failed" });
  }
});

app.post("/pdf-to-ppt", upload.single("pdf"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "PDF required" });
    }

   let text = "";

   try {
     const data = await pdfParse(fs.readFileSync(req.file.path));
     text = data.text?.trim() || "";
   } catch (e) {
     console.log("PDF parse failed:", e.message);
     text = "No readable text found in this PDF.";
   }

    const pptx = new PptxGenJS();
    pptx.layout = "LAYOUT_WIDE";
    pptx.author = "PDF Viewer App";

    const chunks = text.match(/[\s\S]{1,650}/g) || ["No readable text found"];

    chunks.forEach((chunk, index) => {
      const slide = pptx.addSlide();

      slide.background = { color: "FFFFFF" };

      slide.addText(`PDF Slide ${index + 1}`, {
        x: 0.5,
        y: 0.3,
        w: 12.3,
        h: 0.5,
        fontSize: 22,
        bold: true,
        color: "2E1065",
      });

      slide.addText(chunk, {
        x: 0.5,
        y: 1.0,
        w: 12.3,
        h: 5.5,
        fontSize: 13,
        color: "111827",
        fit: "shrink",
        breakLine: false,
      });
    });

    const buffer = await pptx.write({ outputType: "nodebuffer" });

    res.setHeader(
      "Content-Type",
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    );
    res.setHeader("Content-Disposition", 'attachment; filename="converted.pptx"');
    res.send(buffer);
  } catch (error) {
    console.error("PDF TO PPT ERROR:", error);
    res.status(500).json({ error: error.message || "PDF to PPT failed" });
  }
});

app.post("/pdf-to-excel", upload.single("pdf"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "PDF required" });
    }

    let text = "";

    try {
      const data = await pdfParse(fs.readFileSync(req.file.path));
      text = data.text?.trim() || "";
    } catch (e) {
      console.log("PDF parse failed:", e.message);
      text = "No readable text found in this PDF.";
    }

    const rows = text
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean)
      .map((line, index) => [index + 1, line]);

    const workbook = XLSX.utils.book_new();

    const worksheet = XLSX.utils.aoa_to_sheet([
      ["S.No", "PDF Extracted Text"],
      ...rows,
    ]);

    worksheet["!cols"] = [
      { wch: 8 },
      { wch: 100 },
    ];

    XLSX.utils.book_append_sheet(workbook, worksheet, "PDF Data");

    const buffer = XLSX.write(workbook, {
      type: "buffer",
      bookType: "xlsx",
    });

    res.setHeader(
      "Content-Type",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    );
    res.setHeader("Content-Disposition", 'attachment; filename="converted.xlsx"');
    res.send(buffer);
  } catch (error) {
    console.error("PDF TO EXCEL ERROR:", error);
    res.status(500).json({ error: error.message || "PDF to Excel failed" });
  }
});
app.post("/rotate-pdf", upload.single("pdf"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "PDF required" });

    const pdfDoc = await PDFDocument.load(fs.readFileSync(req.file.path));
    pdfDoc.getPages().forEach((page) => {
      const current = page.getRotation().angle;
      page.setRotation(degrees(current + 90));
    });

    const bytes = await pdfDoc.save();

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", 'attachment; filename="rotated.pdf"');
    res.send(Buffer.from(bytes));
  } catch (error) {
    console.error("ROTATE PDF ERROR:", error);
    res.status(500).json({ error: "Rotate PDF failed" });
  }
});

app.post("/add-page-numbers", upload.single("pdf"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "PDF required" });

    const pdfDoc = await PDFDocument.load(fs.readFileSync(req.file.path));
    const font = await pdfDoc.embedFont(StandardFonts.Helvetica);

    const pages = pdfDoc.getPages();

    pages.forEach((page, index) => {
      const { width } = page.getSize();
      page.drawText(`${index + 1}`, {
        x: width / 2,
        y: 25,
        size: 12,
        font,
        color: rgb(0.2, 0.2, 0.2),
      });
    });

    const bytes = await pdfDoc.save();

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", 'attachment; filename="numbered.pdf"');
    res.send(Buffer.from(bytes));
  } catch (error) {
    console.error("PAGE NUMBER ERROR:", error);
    res.status(500).json({ error: "Add page numbers failed" });
  }
});

app.post("/add-watermark", upload.single("pdf"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "PDF required" });

    const watermarkText = req.body.watermark || "PDF Viewer App";

    const pdfDoc = await PDFDocument.load(fs.readFileSync(req.file.path));
    const font = await pdfDoc.embedFont(StandardFonts.HelveticaBold);

    pdfDoc.getPages().forEach((page) => {
      const { width, height } = page.getSize();

      page.drawText(watermarkText, {
        x: width / 4,
        y: height / 2,
        size: 38,
        font,
        color: rgb(0.7, 0.7, 0.7),
        rotate: degrees(-35),
        opacity: 0.35,
      });
    });

    const bytes = await pdfDoc.save();

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", 'attachment; filename="watermarked.pdf"');
    res.send(Buffer.from(bytes));
  } catch (error) {
    console.error("WATERMARK ERROR:", error);
    res.status(500).json({ error: "Add watermark failed" });
  }
});

app.post("/crop-pdf", upload.single("pdf"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "PDF required" });

    const pdfDoc = await PDFDocument.load(fs.readFileSync(req.file.path));

    pdfDoc.getPages().forEach((page) => {
      const { width, height } = page.getSize();

      page.setCropBox(
        25,
        25,
        width - 50,
        height - 50
      );
    });

    const bytes = await pdfDoc.save();

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", 'attachment; filename="cropped.pdf"');
    res.send(Buffer.from(bytes));
  } catch (error) {
    console.error("CROP PDF ERROR:", error);
    res.status(500).json({ error: "Crop PDF failed" });
  }
});
app.listen(5000, "0.0.0.0", () => {
  console.log("Server running on port 5000");
});
