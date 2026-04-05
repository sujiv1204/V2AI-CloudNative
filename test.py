import pyttsx3

engine = pyttsx3.init()
engine.save_to_file(
    "Artificial intelligence is transforming industries. It is used in healthcare, finance, and education to improve efficiency and automate tasks.",
    "data/sample_long.wav"
)
engine.runAndWait()