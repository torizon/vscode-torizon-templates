#!/usr/bin/env node

import { DeviceDetection } from "apollox";
import * as fs from "fs";
import { exit } from "process";

const args = process.argv.slice(2);

async function main() {
    // fetch network devices from the file
    const nets = JSON.parse(
        fs.readFileSync(`${process.env.HOME}/.tcd/scan.json`, "utf8")
    );

    // connect to the arg1 device
    let id = 0
    for (const net of nets) {
        if (id == args[0]) {
            // disable console.log
            const _clTmp = console.log;
            console.log = function() {
                // write to the /home/user/.tcd/connect.log
                fs.appendFileSync(
                    `${process.env.HOME}/.tcd/connect.log`,
                    `${JSON.stringify(arguments)}\n`
                );
            };

            const td = await DeviceDetection.ConnectToDevice(
                net,
                args[1], // login
                args[2], // password
                args[3]  // host ip
            );

            // enable console.log
            console.log = _clTmp;

            // dump to file
            let _devsConnected = [];
            if (fs.existsSync(`${process.env.HOME}/.tcd/connected.json`)) {
                _devsConnected = JSON.parse(
                    fs.readFileSync(`${process.env.HOME}/.tcd/connected.json`, "utf8")
                );
            }

            let _devJson = td;
            _devJson["__pass__"] = args[2];
            _devsConnected.push(_devJson);

            fs.writeFileSync(
                `${process.env.HOME}/.tcd/connected.json`,
                JSON.stringify(_devsConnected, null, 4)
            );

            exit(0);
            break;
        }

        id++;
    }

    // not found
    console.log(JSON.stringify([]));
    exit(404);
}

main();
