def chunk_text(text, max_length=500):
    if not text:
        return []

    words = text.split()
    return [
        " ".join(words[i:i + max_length])
        for i in range(0, len(words), max_length)
    ]