"""Reflow user-supplied PDFs into UTF-8 text assets for the in-app reader.

Run with: python3 -m pip install pymupdf && python3 tool/extract_local_books.py
The source PDFs are deliberately not bundled in the Flutter app.
"""

from pathlib import Path
import re
from statistics import median

import pymupdf


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "no\u0323\u0302i dung sa\u0301ch"
DEST = ROOT / "assets" / "books"

# Keys match Open Library work IDs used by assets/data/catalog_30.json.
BOOKS = {
    "OL17930368W": "Atomic habits.pdf",
    "OL10263W": "The Little Prince.pdf",
    "OL82563W": "harry potter/1. Harry Potter and the Sorcerer’s Stone.pdf",
    "OL1168083W": "1984 by Orwell.pdf",
    "OL3140822W": "to kill a mockingbird.pdf",
    "OL1168007W": "Animal Farm by George Orwell.pdf",
    "OL796465W": "he-Alchemist-Paulo-Coelho.pdf",
    "OL27482W": "The Hobbit by J.R.R. Tolkien.pdf",
    "OL27513W": "The Fellowship of the Ring.pdf",
    "OL71037W": "The Lion the Witch and the Wardrobe.pdf",
    "OL893414W": "Dune by Frank Herbert.pdf",
    "OL64365W": "Brave New World - Aldous Huxley.pdf",
    "OL103123W": "Fahrenheit 451.pdf",
    "OL471576W": "Murder on the Orient Express.pdf",
    "OL483391W": "Charlotte's Web.pdf",
    "OL1063267W": "How to Win Friends and Influence People - Dale Carnegie.pdf",
    "OL2629977W": "The 7 Habits of Highly Effective People.pdf",
    "OL17713267W": "Deep Work.pdf",
    "OL21640039W": "The Psychology of Money.pdf",
}


def reflow_block(raw: str) -> str:
    # PDF line wraps are layout artifacts; keep actual block boundaries as paragraphs.
    raw = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", raw)
    raw = re.sub(r"(?<=\w)-\s*\n\s*(?=[a-z])", "", raw)
    raw = re.sub(r"\s*\n\s*", " ", raw)
    return re.sub(r"[ \t]+", " ", raw).strip()


def layout_paragraphs(blocks: list[str]) -> list[str]:
    short_blocks = median(map(len, blocks)) < 130
    paragraphs: list[str] = []
    pending = ""

    def flush() -> None:
        nonlocal pending
        if pending:
            paragraphs.append(pending)
            pending = ""

    for block in blocks:
        heading = len(block) < 90 and bool(
            re.match(r"^(chapter|part|book|prologue|epilogue)\b", block, re.I)
            or (len(block) > 3 and block.isupper())
        )
        if heading:
            flush()
            paragraphs.append(block)
        elif short_blocks:
            pending = f"{pending} {block}".strip()
            if len(pending) >= 350 and re.search(r'[.!?][”"’]?$', pending):
                flush()
        else:
            flush()
            paragraphs.append(block)
    flush()

    result: list[str] = []
    for paragraph in paragraphs:
        while len(paragraph) > 900:
            cuts = [m.end() for m in re.finditer(r'[.!?][”"’]?\s+', paragraph[:900])]
            cut = max((i for i in cuts if i >= 350), default=0)
            if not cut:
                cut = paragraph.rfind(" ", 350, 900)
            if cut <= 0:
                cut = 900
            result.append(paragraph[:cut].strip())
            paragraph = paragraph[cut:].strip()
        if paragraph:
            result.append(paragraph)
    return result


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    for work_id, filename in BOOKS.items():
        path = SOURCE / filename
        if not path.is_file():
            raise FileNotFoundError(path)
        document = pymupdf.open(path)
        blocks: list[str] = []
        for page in document:
            for block in page.get_text("blocks", sort=True):
                if block[6] != 0:
                    continue
                text = reflow_block(block[4])
                if not text or re.fullmatch(r"[\W_]*\d{1,4}[\W_]*", text):
                    continue
                blocks.append(text)
        paragraphs = layout_paragraphs(blocks)
        if sum(map(len, paragraphs)) < 20_000:
            raise ValueError(f"Too little extractable text: {filename}")
        output = DEST / f"local_{work_id}.txt"
        output.write_text("\n\n".join(paragraphs) + "\n", encoding="utf-8")
        print(f"{work_id}: {len(paragraphs)} paragraphs, {output.stat().st_size} bytes")


if __name__ == "__main__":
    main()
