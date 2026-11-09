// Startup file for cPanel "Setup Node.js App" (Phusion Passenger).
// The Next.js server lives in ./server with its own dependencies, because the cPanel Node.js
// selector reserves "node_modules" in the application root for its virtual environment.
process.env.NODE_ENV = process.env.NODE_ENV || "production";
require("./server/server.js");
