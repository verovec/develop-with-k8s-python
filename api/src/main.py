

import uvicorn
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def get_root():
    return {"message": "I am running !"}


if __name__ == "__main__":
    uvicorn.run("__main__:app", host="0.0.0.0", port=8080, reload=True, workers=2)