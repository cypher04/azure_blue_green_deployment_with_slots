const express = require("express");
const app = express();

app.get("/", (req, res) => {
  app.disable("x-powered-by");
  res.send("Hello from Terraform + Docker + Azure!");
});

app.listen(3000, () => {
  console.log("App running on port 3000");
});
