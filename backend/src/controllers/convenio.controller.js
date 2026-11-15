const convenioService = require("../services/convenio.service");

const getConvenios = async (req, res) => {
    try {
        const convenios = await convenioService.listarConvenios();
        res.status(200).json({
            success: true,
            data: convenios
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Error al obtener los convenios",
            error: error.message
        });
    }
};

const getConvenioById = async (req, res) => {
    try {
        const { id } = req.params;
        const convenio = await convenioService.obtenerConvenioPorId(id);

        if (!convenio) {
            return res.status(404).json({
                success: false,
                message: "Convenio no encontrado"
            });
        }

        res.status(200).json({
            success: true,
            data: convenio
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Error al obtener el convenio",
            error: error.message
        });
    }
};

const postConvenio = async (req, res) => {
    try {
        const { nombreEmpresa } = req.body;

        if (!nombreEmpresa || nombreEmpresa.trim() === "") {
            return res.status(400).json({
                success: false,
                message: "El nombre de la empresa es obligatorio"
            });
        }

        const nuevoConvenio = await convenioService.crearConvenio(req.body);
        res.status(201).json({
            success: true,
            message: "Convenio registrado exitosamente",
            data: nuevoConvenio
        });
    } catch (error) {
        if (error.code === "P2002") {
            return res.status(400).json({
                success: false,
                message: "Ya existe un convenio registrado con ese RFC"
            });
        }
        res.status(500).json({
            success: false,
            message: "Error al crear el convenio",
            error: error.message
        });
    }
};

const putConvenio = async (req, res) => {
    try {
        const { id } = req.params;
        const convenioActualizado = await convenioService.actualizarConvenio(id, req.body);

        res.status(200).json({
            success: true,
            message: "Convenio actualizado correctamente",
            data: convenioActualizado
        });
    } catch (error) {
        if (error.code === "P2025") {
            return res.status(404).json({
                success: false,
                message: "Convenio no encontrado"
            });
        }
        res.status(500).json({
            success: false,
            message: "Error al actualizar el convenio",
            error: error.message
        });
    }
};

const deleteConvenio = async (req, res) => {
    try {
        const { id } = req.params;
        await convenioService.desactivarConvenio(id);

        res.status(200).json({
            success: true,
            message: "Convenio desactivado correctamente"
        });
    } catch (error) {
        if (error.code === "P2025") {
            return res.status(404).json({
                success: false,
                message: "Convenio no encontrado"
            });
        }
        res.status(500).json({
            success: false,
            message: "Error al desactivar el convenio",
            error: error.message
        });
    }
};

module.exports = {
    getConvenios,
    getConvenioById,
    postConvenio,
    putConvenio,
    deleteConvenio
};