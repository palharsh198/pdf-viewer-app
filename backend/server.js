const mongoose = require("mongoose");
const express = require("express");
const multer = require("multer");
const pdfParse = require("pdf-parse");
const { Document, Packer, Paragraph } = require("docx");
const cors = require("cors");
const fs = require("fs");
const path = require("path");
const app = express();
const Tesseract = require("tesseract.js");
const pdfPoppler = require("pdf-poppler");
const sharp = require("sharp");

app.use(cors());
app.use(express.json());
app.use("/uploads", express.static("uploads"));
mongoose
  .connect("mongodb://127.0.0.1:27017/pdf_viewer_app")
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
      fileUrl: `http://192.168.29.74:5000/uploads/${req.file.filename}`,
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

      await pdfPoppler.convert(req.file.path, {
        format: "png",
        out_dir: outputDir,
        out_prefix: prefix,
        page: null,
        resolution: 100,
      });

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

app.listen(5000, "0.0.0.0", () => {
  console.log("Server running on port 5000");
});
