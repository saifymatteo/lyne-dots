.pragma library

// Calculator inference for the launcher's apps mode: whether a search term
// is worth sending to qalc, and the expression to send. Conservative on
// purpose, so app names ("7zip", "gimp 2", "steam") never trigger it.
// Tested by tests/js/calc.test.js

// Currency codes and symbols a bare amount ("100usd", "€50") may carry
var CURRENCIES = ["USD", "EUR", "GBP", "JPY", "CNY", "CHF", "CAD", "AUD", "NZD", "SEK", "NOK", "DKK", "ISK", "PLN", "CZK", "HUF", "RON", "BGN", "TRY", "RUB", "UAH", "INR", "IDR", "MYR", "SGD", "THB", "VND", "PHP", "KRW", "HKD", "TWD", "BRL", "MXN", "ARS", "CLP", "COP", "PEN", "ZAR", "EGP", "NGN", "KES", "ILS", "AED", "SAR", "QAR", "KWD", "PKR", "BDT", "LKR", "BTC"];
var CURRENCY_SYMBOLS = "$€£¥₹₩₽₺₫฿";

// Units a number may be followed by ("5km", "3 lb"). Longer names first in
// the regex is not needed: the unit must end the term
var UNITS = ["mm", "cm", "m", "km", "in", "inch", "inches", "ft", "foot", "feet", "yd", "mi", "mile", "miles", "nmi", "mg", "g", "kg", "t", "lb", "lbs", "oz", "st", "ml", "cl", "dl", "l", "gal", "qt", "pt", "floz", "cup", "cups", "c", "f", "k", "°c", "°f", "celsius", "fahrenheit", "kelvin", "b", "kb", "mb", "gb", "tb", "kib", "mib", "gib", "tib", "bit", "bits", "byte", "bytes", "ms", "s", "sec", "min", "h", "hr", "hrs", "hour", "hours", "day", "days", "week", "weeks", "month", "months", "year", "years", "mph", "kph", "kmh", "km/h", "m/s", "knot", "knots", "w", "kw", "mw", "kwh", "wh", "j", "kj", "cal", "kcal", "pa", "kpa", "bar", "psi", "atm", "hz", "khz", "mhz", "ghz", "ha", "acre", "acres", "deg", "rad", "%"];

var MATH_FUNCTIONS = /^(sqrt|cbrt|root|sin|cos|tan|asin|acos|atan|sinh|cosh|tanh|log|log2|log10|ln|exp|abs|round|floor|ceil|trunc|factorial|gcd|lcm|max|min|sum|mean|avg)\s*\(/i;

var NUMBER = "[0-9]+(?:[.,][0-9]+)*";

function _escape(s) {
    return s.replace(/[.*+?^${}()|[\]\\/]/g, "\\$&");
}

var _currencyCode = new RegExp("^(" + CURRENCIES.join("|") + ")$", "i");
var _unit = new RegExp("^(" + UNITS.map(_escape).join("|") + ")$", "i");
// "100usd", "50 EUR", "$100", "100 €"
var _bareCurrency = new RegExp("^(?:([" + CURRENCY_SYMBOLS + "])\\s*(" + NUMBER + ")|(" + NUMBER + ")\\s*([" + CURRENCY_SYMBOLS + "]|[A-Za-z]{3}))$");
// A number and the word after it, the whole term ("5km", "3 lb")
var _numberWord = new RegExp("^(" + NUMBER + ")\\s*(\\S+)$");

// Currency of a bare amount ("100usd" → "USD", "$5" → "$"), else ""
function bareCurrency(term) {
    var m = (term || "").trim().match(_bareCurrency);
    if (!m)
        return "";
    var cur = m[1] || m[4];
    if (CURRENCY_SYMBOLS.indexOf(cur) !== -1)
        return cur;
    return _currencyCode.test(cur) ? cur.toUpperCase() : "";
}

function looksLikeCalc(term) {
    var s = (term || "").trim();
    if (s === "")
        return false;
    if (MATH_FUNCTIONS.test(s))
        return true;
    if (!/[0-9]/.test(s))
        return false;
    // An operator between two operands: "2*21", "(3+4)/2", "2^10", "20% of 150"
    if (/[0-9)]\s*[-+*\/^×÷]\s*[0-9(.]/.test(s) || /[0-9]\s*%\s*of\s+[0-9]/i.test(s))
        return true;
    // A conversion after a number: "5 km to mi", "255 in hex", "100 usd -> eur"
    if (/[0-9][^]*\s(to|in|->)\s+\S/i.test(s))
        return true;
    if (bareCurrency(s) !== "")
        return true;
    var m = s.match(_numberWord);
    return m !== null && _unit.test(m[2]);
}

// The expression for qalc: a bare amount in another currency gets
// " to <home>" so "100usd" answers in the home currency
function calcExpression(term, homeCurrency) {
    var s = (term || "").trim();
    var home = (homeCurrency || "").trim();
    var cur = bareCurrency(s);
    if (home === "" || cur === "" || cur.toUpperCase() === home.toUpperCase())
        return s;
    return s + " to " + home;
}

// qalc's answer is worth showing: not an error and not the input echoed back
function usefulResult(term, result) {
    var r = (result || "").trim();
    if (r === "" || /^error/i.test(r))
        return false;
    var squash = function (x) {
        return x.toLowerCase().replace(/\s+/g, "");
    };
    return squash(r) !== squash(term || "");
}
