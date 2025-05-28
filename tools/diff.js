#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { EOL } from 'os'; // For platform-independent newlines

// node diff.js  $HOME/dart_git/src $HOME/dart_git/lib/src missing_files_report.txt
// --- Helper function to get a fully normalized base path ---
// This function will now handle extension removal, case, hyphens, underscores,
// and path separator normalization for the key used in comparison.
function getNormalizedBasePath(relativeFilePath) {
    const directory = path.dirname(relativeFilePath); // e.g., "utils" or "."
    const extension = path.extname(relativeFilePath); // e.g., ".js"
    const filenameWithoutExtension = path.basename(relativeFilePath, extension); // e.g., "git-list-pack"

    // Normalize the filename part: lowercase, remove hyphens and underscores
    const normalizedFilename = filenameWithoutExtension.toLowerCase().replace(/[-_]/g, ''); // e.g., "gitlistpack"

    // Normalize the directory part: lowercase, convert \ to /, remove hyphens and underscores
    if (directory === '.') { // File is in the root of the baseDir (relative to srcDir or targetDir)
        return normalizedFilename;
    }

    // For files in subdirectories
    const normalizedDirectory = directory
        .toLowerCase()
        .replace(/\\/g, '/') // Convert Windows backslashes to forward slashes
        .replace(/[-_]/g, ''); // Remove hyphens/underscores from directory names too

    return `${normalizedDirectory}/${normalizedFilename}`; // e.g., "utils/gitlistpack"
}


// --- Helper function to get all files recursively ---
function getAllFiles(dirPath, baseDir = dirPath, fileList = new Set()) {
    try {
        const files = fs.readdirSync(dirPath);
        files.forEach(file => {
            const filePath = path.join(dirPath, file);
            try {
                if (fs.statSync(filePath).isDirectory()) {
                    getAllFiles(filePath, baseDir, fileList);
                } else {
                    // Store paths relative to the initial baseDir
                    fileList.add(path.relative(baseDir, filePath));
                }
            } catch (statError) {
                if (statError.code === 'ENOENT' || statError.code === 'EACCES') {
                    // console.warn(`Warning: Could not stat ${filePath}, skipping. Error: ${statError.message}`);
                } else { throw statError; }
            }
        });
    } catch (error) {
        if (error.code === 'ENOENT') {} // Base directory itself doesn't exist (handled in main)
        else if (error.code === 'EACCES') { console.warn(`Warning: Permission denied for directory ${dirPath}, skipping its contents.`); }
        else { console.error(`Error reading directory ${dirPath}: ${error.message}`); }
    }
    return fileList;
}

// --- Main script logic ---
async function compareDirectories(srcDir, targetDir, outputFilePath) {
    const resolvedSrcDir = path.resolve(srcDir);
    const resolvedTargetDir = path.resolve(targetDir);
    const resolvedOutputFilePath = outputFilePath ? path.resolve(outputFilePath) : null;

    let outputLines = [];
    const logAndStore = (message) => {
        console.log(message);
        outputLines.push(message);
    };

    logAndStore(`Source Directory: ${resolvedSrcDir}`);
    logAndStore(`Target Directory: ${resolvedTargetDir}`);
    if (resolvedOutputFilePath) { logAndStore(`Output File: ${resolvedOutputFilePath}`); }
    logAndStore(`Comparison Mode: Ignoring file extensions, case, underscores (_), and hyphens (-).`);
    logAndStore('');

    if (!fs.existsSync(resolvedSrcDir) || !fs.statSync(resolvedSrcDir).isDirectory()) {
        const errorMsg = `Error: Source directory "${resolvedSrcDir}" does not exist or is not a directory.`;
        console.error(errorMsg);
        if (resolvedOutputFilePath) await fs.promises.writeFile(resolvedOutputFilePath, errorMsg + EOL, 'utf-8').catch(e => console.error("Error writing error to output file:", e));
        process.exit(1);
    }
    if (!fs.existsSync(resolvedTargetDir) || !fs.statSync(resolvedTargetDir).isDirectory()) {
        const errorMsg = `Error: Target directory "${resolvedTargetDir}" does not exist or is not a directory.`;
        console.error(errorMsg);
        if (resolvedOutputFilePath) await fs.promises.writeFile(resolvedOutputFilePath, errorMsg + EOL, 'utf-8').catch(e => console.error("Error writing error to output file:", e));
        process.exit(1);
    }

    const srcFiles = getAllFiles(resolvedSrcDir); // Returns Set of relative paths e.g. {"utils/file.js", "other.txt"}
    const targetFilesRaw = getAllFiles(resolvedTargetDir); // Same format

    const normalizedTargetBasePaths = new Set();
    // ---- START DEBUGGING SECTION (Optional: Uncomment to debug specific files) ----
    // console.log("\n--- DEBUG: Normalizing Target Files ---");
    // ---- END DEBUGGING SECTION ----
    targetFilesRaw.forEach(relativeTargetFile => {
        const normalized = getNormalizedBasePath(relativeTargetFile);
        // ---- START DEBUGGING SECTION (Optional: Uncomment to debug specific files) ----
        // if (relativeTargetFile.includes('git_list_pack') || relativeTargetFile.includes('YOUR_OTHER_TARGET_FILENAME_PART')) {
        //     console.log(`  TARGET RAW: "${relativeTargetFile}"`);
        //     console.log(`    -> NORMALIZED: "${normalized}"`);
        // }
        // ---- END DEBUGGING SECTION ----
        normalizedTargetBasePaths.add(normalized);
    });

    const missingInTarget = {};
    let foundMissing = false;

    // ---- START DEBUGGING SECTION (Optional: Uncomment to debug specific files) ----
    // console.log("\n--- DEBUG: Comparing Source Files ---");
    // ---- END DEBUGGING SECTION ----
    srcFiles.forEach(relativeSrcFilePath => {
        const normalizedSrcBasePath = getNormalizedBasePath(relativeSrcFilePath);
        // ---- START DEBUGGING SECTION (Optional: Uncomment to debug specific files) ----
        // let isMatchCandidate = relativeSrcFilePath.includes('git-list-pack') || relativeSrcFilePath.includes('YOUR_OTHER_SOURCE_FILENAME_PART');
        // if (isMatchCandidate) {
        //     console.log(`\n  SOURCE RAW: "${relativeSrcFilePath}"`);
        //     console.log(`    -> NORMALIZED: "${normalizedSrcBasePath}"`);
        //     console.log(`    -> IS IN TARGET SET? ${normalizedTargetBasePaths.has(normalizedSrcBasePath)} (Looking for: "${normalizedSrcBasePath}")`);
        // }
        // ---- END DEBUGGING SECTION ----

        if (!normalizedTargetBasePaths.has(normalizedSrcBasePath)) {
            // ---- START DEBUGGING SECTION (Optional: Uncomment to debug specific files) ----
            // if (isMatchCandidate) {
            //     console.log(`    -> RESULT: NOT FOUND in target set. Marked as missing.`);
            // }
            // ---- END DEBUGGING SECTION ----
            foundMissing = true;
            const dirName = path.dirname(relativeSrcFilePath);
            const fileName = path.basename(relativeSrcFilePath); // Keep original filename for display
            const displayDirName = (dirName === '.') ? '(root directory)' : dirName;
            if (!missingInTarget[displayDirName]) { missingInTarget[displayDirName] = []; }
            missingInTarget[displayDirName].push(fileName);
        }
        // ---- START DEBUGGING SECTION (Optional: Uncomment to debug specific files) ----
        // else if (isMatchCandidate) {
        //     console.log(`    -> RESULT: FOUND in target set. Not missing.`);
        // }
        // ---- END DEBUGGING SECTION ----
    });
    // ---- START DEBUGGING SECTION (Optional: Uncomment to debug specific files) ----
    // console.log("--- DEBUG: End of comparison ---\n");
    // ---- END DEBUGGING SECTION ----

    if (!foundMissing) {
        logAndStore("All files from source directory (after normalization: ignore extension, case, underscores, and hyphens) have a corresponding normalized base name in the target directory.");
    } else {
        logAndStore("Files in Source Directory for which NO corresponding normalized base name (ignoring extension, case, underscores, and hyphens) was found in Target Directory (grouped by directory):");
        logAndStore('');
        const sortedDirs = Object.keys(missingInTarget).sort();
        sortedDirs.forEach(dir => {
            logAndStore(`Directory: ${dir}`);
            missingInTarget[dir].sort().forEach(file => { logAndStore(`  - ${file}`); });
            logAndStore('');
        });
    }

    if (resolvedOutputFilePath) {
        try {
            const outputContent = outputLines.join(EOL) + EOL;
            await fs.promises.writeFile(resolvedOutputFilePath, outputContent, 'utf-8');
            console.log(`\nOutput successfully written to ${resolvedOutputFilePath}`);
        } catch (error) {
            console.error(`\nError writing output to file "${resolvedOutputFilePath}": ${error.message}`);
        }
    }
}

// --- Script execution ---
if (process.argv.length < 4 || process.argv.length > 5) {
    const scriptName = path.basename(process.argv[1]);
    console.log(`Usage: node ${scriptName} <source_directory> <target_directory> [output_file.txt]`);
    console.log("\nArguments:");
    console.log("  <source_directory>   Path to the source directory.");
    console.log("  <target_directory>   Path to the target directory.");
    console.log("  [output_file.txt]    (Optional) Path to the file where results will be saved.");
    console.log("\nNote: To run this ES Module script:");
    console.log("1. Save it with a .mjs extension (e.g., compare_dirs.mjs).");
    console.log("   OR");
    console.log("2. Save it with a .js extension and ensure your project's package.json contains `\"type\": \"module\"`.");
    process.exit(1);
}

const srcDirectoryArg = process.argv[2];
const targetDirectoryArg = process.argv[3];
const outputFileArg = process.argv[4];

try {
    await compareDirectories(srcDirectoryArg, targetDirectoryArg, outputFileArg);
} catch (error) {
    console.error("An unexpected error occurred during script execution:", error);
    if (outputFileArg) {
        const resolvedOutputFilePath = path.resolve(outputFileArg);
        // Ensure error message is written even in unexpected failures
        const errorMessageContent = `An unexpected error occurred: ${error.message || String(error)}${EOL}${error.stack ? 'Stack: ' + error.stack + EOL : ''}`;
        await fs.promises.writeFile(resolvedOutputFilePath, errorMessageContent, 'utf-8')
            .catch(e => console.error("Error writing final error to output file:", e));
    }
    process.exit(1);
}