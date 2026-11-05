-- CreateEnum
CREATE TYPE "Rol" AS ENUM ('ADMIN', 'GERENTE', 'TECNICO', 'RECEPCIONISTA', 'CLIENTE_B2B');

-- CreateEnum
CREATE TYPE "EstatusOrden" AS ENUM ('RECEPCION', 'DIAGNOSTICO', 'REPARACION', 'CONTROL_CALIDAD', 'ENTREGA');

-- CreateEnum
CREATE TYPE "Prioridad" AS ENUM ('BAJA', 'MEDIA', 'ALTA', 'URGENTE');

-- CreateTable
CREATE TABLE "Usuario" (
    "id" TEXT NOT NULL,
    "nombre" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "rol" "Rol" NOT NULL DEFAULT 'RECEPCIONISTA',
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "convenioId" TEXT,
    "creadoEn" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "actualizadoEn" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Usuario_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Convenio" (
    "id" TEXT NOT NULL,
    "nombreEmpresa" TEXT NOT NULL,
    "razonSocial" TEXT,
    "rfc" TEXT,
    "contacto" TEXT,
    "email" TEXT,
    "telefono" TEXT,
    "descuentoPorcentaje" DECIMAL(5,2) NOT NULL DEFAULT 0,
    "comisionPorcentaje" DECIMAL(5,2) NOT NULL DEFAULT 0,
    "condicionesGarantia" TEXT,
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "creadoEn" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "actualizadoEn" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Convenio_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Equipo" (
    "id" TEXT NOT NULL,
    "tipo" TEXT NOT NULL,
    "marca" TEXT,
    "modelo" TEXT,
    "numeroSerie" TEXT,
    "descripcion" TEXT,
    "convenioId" TEXT,
    "creadoEn" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "actualizadoEn" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Equipo_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OrdenServicio" (
    "id" TEXT NOT NULL,
    "folio" TEXT NOT NULL,
    "equipoId" TEXT NOT NULL,
    "tecnicoId" TEXT,
    "recepcionistaId" TEXT,
    "estatus" "EstatusOrden" NOT NULL DEFAULT 'RECEPCION',
    "prioridad" "Prioridad" NOT NULL DEFAULT 'MEDIA',
    "diagnostico" TEXT,
    "reparacionRealizada" TEXT,
    "costo" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "comision" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "fechaRecepcion" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "fechaEntrega" TIMESTAMP(3),
    "creadoEn" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "actualizadoEn" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "OrdenServicio_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BitacoraOrden" (
    "id" TEXT NOT NULL,
    "ordenId" TEXT NOT NULL,
    "estatusAnterior" "EstatusOrden",
    "estatusNuevo" "EstatusOrden" NOT NULL,
    "nota" TEXT,
    "fecha" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BitacoraOrden_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Usuario_email_key" ON "Usuario"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Convenio_rfc_key" ON "Convenio"("rfc");

-- CreateIndex
CREATE UNIQUE INDEX "OrdenServicio_folio_key" ON "OrdenServicio"("folio");

-- AddForeignKey
ALTER TABLE "Usuario" ADD CONSTRAINT "Usuario_convenioId_fkey" FOREIGN KEY ("convenioId") REFERENCES "Convenio"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Equipo" ADD CONSTRAINT "Equipo_convenioId_fkey" FOREIGN KEY ("convenioId") REFERENCES "Convenio"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OrdenServicio" ADD CONSTRAINT "OrdenServicio_equipoId_fkey" FOREIGN KEY ("equipoId") REFERENCES "Equipo"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OrdenServicio" ADD CONSTRAINT "OrdenServicio_tecnicoId_fkey" FOREIGN KEY ("tecnicoId") REFERENCES "Usuario"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OrdenServicio" ADD CONSTRAINT "OrdenServicio_recepcionistaId_fkey" FOREIGN KEY ("recepcionistaId") REFERENCES "Usuario"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BitacoraOrden" ADD CONSTRAINT "BitacoraOrden_ordenId_fkey" FOREIGN KEY ("ordenId") REFERENCES "OrdenServicio"("id") ON DELETE CASCADE ON UPDATE CASCADE;
