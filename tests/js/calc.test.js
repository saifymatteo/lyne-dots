const test = require("node:test");
const assert = require("node:assert/strict");
const { load } = require("./load");

const C = load("services/calc.js");

test("calculations and conversions are inferred", () => {
    for (const term of ["2*21", "100usd", "5 km to mi", "50 EUR", "$100", "(3+4)/2", "2^10", "20% of 150", "sqrt(2)", "5km", "3 lb", "255 in hex"])
        assert.equal(C.looksLikeCalc(term), true, term);
});

test("app names never trigger the calculator", () => {
    for (const term of ["firefox", "steam", "code", "7zip", "gimp 2", "0ad", "2048", "1password", "3d", "k3b", "to do", "", "x264"])
        assert.equal(C.looksLikeCalc(term), false, term);
});

test("a bare currency amount goes to the home currency", () => {
    assert.equal(C.calcExpression("100usd", "MYR"), "100usd to MYR");
    assert.equal(C.calcExpression("50 EUR", "MYR"), "50 EUR to MYR");
    assert.equal(C.calcExpression("100usd", ""), "100usd");
    assert.equal(C.calcExpression("100 myr", "MYR"), "100 myr");
    assert.equal(C.calcExpression("100 usd to eur", "MYR"), "100 usd to eur");
    assert.equal(C.calcExpression("2*21", "MYR"), "2*21");
    assert.equal(C.calcExpression("5km", "MYR"), "5km");
});

test("errors and echoes aren't results", () => {
    assert.equal(C.usefulResult("2*21", "42"), true);
    assert.equal(C.usefulResult("5 s", "5 s"), false);
    assert.equal(C.usefulResult("5s", "5 s"), false);
    assert.equal(C.usefulResult("x", "error: unknown"), false);
    assert.equal(C.usefulResult("x", ""), false);
});
