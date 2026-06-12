# mcp_search_server.py
import httpx
import os
import re
from dotenv import load_dotenv
from mcp.server.fastmcp import FastMCP

load_dotenv()
mcp = FastMCP("web-search-mcp")


@mcp.tool()
async def search_web(query: str, max_results: int = 3) -> str:
    """
    Search the internet for current, up-to-date information.
    Use this when the question involves recent events, releases,
    documentation updates, or anything that may have changed
    after the model's training cutoff.
    """
    max_results = max(1, min(max_results, 5))

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "https://api.tavily.com/search",
            json={
                "api_key": os.getenv("TAVILY_API_KEY"),
                "query": query,
                "max_results": max_results,
                "include_answer": True,
            },
            timeout=10
        )
        data = resp.json()

    output = []
    if data.get("answer"):
        output.append(f"Quick answer: {data['answer']}\n")

    for i, r in enumerate(data.get("results", []), 1):
        output.append(
            f"[{i}] {r['title']}\n"
            f"    URL: {r['url']}\n"
            f"    {r['content'][:400]}\n"
        )

    return "\n".join(output)


@mcp.tool()
async def fetch_page(url: str) -> str:
    """
    Fetch the full text content of a specific URL.
    Use after search_web when you need the full article or docs page.
    """
    async with httpx.AsyncClient(follow_redirects=True) as client:
        resp = await client.get(url, timeout=15)
        text = re.sub(r"<[^>]+>", " ", resp.text)
        text = re.sub(r"\s+", " ", text).strip()
        return text[:3000]


if __name__ == "__main__":
    mcp.run()