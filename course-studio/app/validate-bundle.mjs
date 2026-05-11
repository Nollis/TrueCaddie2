import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..", "..");
const schemaFile = path.join(
  repoRoot,
  "shared",
  "course-bundle-schema",
  "course-bundle.v1.schema.json"
);

const ajv = new Ajv2020({
  allErrors: true,
  strict: false
});

addFormats(ajv);

let validatorPromise;

function formatInstancePath(instancePath) {
  return instancePath ? instancePath.replaceAll("/", ".").replace(/^\./, "") : "bundle";
}

function formatError(error) {
  const location = formatInstancePath(error.instancePath);

  switch (error.keyword) {
    case "required":
      return `${location}: missing required property '${error.params.missingProperty}'`;
    case "additionalProperties":
      return `${location}: unexpected property '${error.params.additionalProperty}'`;
    case "type":
      return `${location}: ${error.message}`;
    case "enum":
    case "const":
    case "format":
    case "minItems":
    case "maxItems":
    case "minimum":
    case "maximum":
    case "minLength":
      return `${location}: ${error.message}`;
    default:
      return `${location}: ${error.message ?? error.keyword}`;
  }
}

async function loadValidator() {
  if (!validatorPromise) {
    validatorPromise = readFile(schemaFile, "utf8")
      .then((contents) => JSON.parse(contents))
      .then((schema) => ajv.compile(schema));
  }

  return validatorPromise;
}

export async function validateCourseBundle(bundle) {
  const validator = await loadValidator();
  const valid = validator(bundle);

  return {
    valid: Boolean(valid),
    errors: (validator.errors ?? []).map(formatError)
  };
}

async function main() {
  const filePath = process.argv[2];

  if (!filePath) {
    console.error("Usage: node course-studio/app/validate-bundle.mjs <bundle.json>");
    process.exitCode = 1;
    return;
  }

  const bundle = JSON.parse(await readFile(filePath, "utf8"));
  const validation = await validateCourseBundle(bundle);

  if (!validation.valid) {
    for (const error of validation.errors) {
      console.error(`- ${error}`);
    }
    process.exitCode = 1;
    return;
  }

  console.log(`Bundle is valid: ${bundle.course_id} ${bundle.bundle_version}`);
  console.log(`Holes: ${bundle.holes.length}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
