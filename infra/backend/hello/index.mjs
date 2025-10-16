export const handler = async (event) => {
  return {
    statusCode: 200,
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      ok: true,
      message: "ConstructionOS API is alive",
      time: new Date().toISOString()
    })
  };
};
