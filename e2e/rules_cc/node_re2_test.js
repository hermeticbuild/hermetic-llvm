const RE2 = require("re2");

const re = new RE2("^(hello)\\s+(node-re2)$");
const match = re.exec("hello node-re2");

if (!match || match[1] !== "hello" || match[2] !== "node-re2") {
    throw new Error("node-re2 did not match through the native extension");
}

console.log("loaded node-re2 native extension");
