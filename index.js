const express = require("express");
const cors = require("cors");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());

let events = [];

app.get("/health", (req, res) => {
  res.send("ok");
});

app.post("/events", (req, res) => {
  const { title, description, date, venue, price, organizerEmail } = req.body;

  if (!title || !date || !organizerEmail) {
    return res.status(400).json({ error: "Missing required fields" });
  }

  const newEvent = {
    id: Date.now().toString(),
    title,
    description,
    date,
    venue,
    price,
    organizerEmail,
  };

  events.push(newEvent);
  res.status(201).json(newEvent);
});

app.get("/events", (req, res) => {
  res.json(events);
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log("Server running on port " + PORT);
});
