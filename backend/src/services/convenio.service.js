const prisma = require("../config/database");

const listarConvenios = async () => {
    return await prisma.convenio.findMany({
        orderBy: { creadoEn: "desc" }
    });
};

const obtenerConvenioPorId = async (id) => {
    return await prisma.convenio.findUnique({
        where: { id },
        include: {
            usuarios: {
                select: { id: true, nombre: true, email: true, rol: true }
            },
            equipos: true
        }
    });
};

const crearConvenio = async (datos) => {
    const {
        nombreEmpresa,
        razonSocial,
        rfc,
        contacto,
        email,
        telefono,
        descuentoPorcentaje,
        comisionPorcentaje,
        condicionesGarantia
    } = datos;

    return await prisma.convenio.create({
        data: {
            nombreEmpresa,
            razonSocial,
            rfc,
            contacto,
            email,
            telefono,
            descuentoPorcentaje: descuentoPorcentaje ?? 0,
            comisionPorcentaje: comisionPorcentaje ?? 0,
            condicionesGarantia
        }
    });
};

const actualizarConvenio = async (id, datos) => {
    return await prisma.convenio.update({
        where: { id },
        data: datos
    });
};

const desactivarConvenio = async (id) => {
    return await prisma.convenio.update({
        where: { id },
        data: { activo: false }
    });
};

module.exports = {
    listarConvenios,
    obtenerConvenioPorId,
    crearConvenio,
    actualizarConvenio,
    desactivarConvenio
};