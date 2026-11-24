// Source: ThePeeps191/grok-bot-characters (MIT, Danny Wang).
// Only normalized geometry is shipped; the iOS renderer and animation are native.
const fs = require('fs');
const bot = require('./Vendor/grokbot.cjs');
const names = ['circle','blob','egg','hexagon','triangle','squircle','cloud','clover','flower','heart'];
fs.writeFileSync('INVERTER/Resources/Bot/BotShapes.json', JSON.stringify(Object.fromEntries(names.map(name => [name, Array.from(bot.SHAPES[name].pts)]))));
