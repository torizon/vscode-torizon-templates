#!/usr/bin/env node

import { DeviceDetection } from "apollox";
import { writeFile } from "fs/promises";

async function main() {
    var ix = 0;
    // disable console.log
    const _clTmp = console.log;
    console.log = function() {};

    // show the devices found in async mode
    const devDect = new DeviceDetection((dev) => {
        _clTmp(`\n\t\t ${ix} ➡️  ${dev.Hostname} (${dev.Ip}) \n`);
        ix++;
    });

    const nets = await devDect.ScanDevices();

    // enable console.log
    console.log = _clTmp;

    // save the nets as json at the /home/user/.tcd/scan.json
    await writeFile(
        `${process.env.HOME}/.tcd/scan.json`,
        JSON.stringify(nets, null, 2)
    );
}

main();
