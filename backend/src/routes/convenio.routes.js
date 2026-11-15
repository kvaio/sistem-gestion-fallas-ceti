const { Router } = require("express");
const convenioController = require("../controllers/convenio.controller");

const router = Router();

router.get("/", convenioController.getConvenios);
router.get("/:id", convenioController.getConvenioById);
router.post("/", convenioController.postConvenio);
router.put("/:id", convenioController.putConvenio);
router.delete("/:id", convenioController.deleteConvenio);

module.exports = router;