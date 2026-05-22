const { ALLURE_SERVICE_TOKEN } = process.env;

const allureService = ALLURE_SERVICE_TOKEN
  ? {
      accessToken: ALLURE_SERVICE_TOKEN,
    }
  : undefined;

export default {
  name: "Allure Dart",
  output: "./build/allure-report",
  plugins: {
    awesome: {
      options: {
        groupBy: ["package", "parentSuite", "suite", "subSuite"],
        publish: true,
      },
    },
  },
  ...(allureService ? { allureService } : {}),
};
