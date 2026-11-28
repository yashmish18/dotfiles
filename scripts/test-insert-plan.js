// node scripts/test-insert-plan.js: which workspaces move when one is inserted (Hypr.qml)
const src = require("fs").readFileSync(__dirname + "/../config/quickshell/kajukatli/services/Hypr.qml", "utf8");
const body = src.match(/function insertPlan\(mine: var, others: var, at: int\): var \{\n([\s\S]*?)\n    \}\n/)[1];
const plan = new Function("mine", "others", "at", body);
const check = (mine, others, at, want) => {
    const got = JSON.stringify(plan(mine, others, at));
    if (got !== JSON.stringify(want)) throw new Error(`${mine} at ${at}: ${got}, wanted ${JSON.stringify(want)}`);
};
check([1, 2], [], 2, { 2: 3 });                       // between 1 and 2: 2 moves up, it is not sent last
check([1, 2, 3], [], 1, { 1: 2, 2: 3, 3: 4 });        // before the first
check([1, 2, 3], [], 3, { 3: 4 });
check([1, 2, 5], [], 2, { 2: 3 });                    // a free number absorbs the shift
check([1, 2, 4], [3], 2, { 2: 4, 4: 5 });             // another screen's number is skipped
console.log("insert plan: passed");
