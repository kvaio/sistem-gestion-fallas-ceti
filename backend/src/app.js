const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");

const convenioRoutes = require("./routes/convenio.routes");

const app = express();

app.use(helmet());
app.use(cors({
    origin: process.env.FRONTEND_URL || "http://localhost:5173"
}));

app.use(express.json());
app.use(morgan("dev"));

app.get("/api/health", (req, res) => {
    res.status(200).json({
        success: true,
        message: "Sistema de Gestión de Fallas API funcionando",
        timestamp: new Date().toISOString()
    });
});

// Rutas del módulo de Convenios y Tarifas
app.use("/api/convenios", convenioRoutes);

app.use((req, res) => {
    res.status(404).json({
        success: false,
        message: "Ruta no encontrada"
    });
});

module.exports = app;