# EMO 💙

**An offline-first, emotionally intelligent AI companion for Android.**

EMO is a privacy-first mental wellness chat application that runs entirely on-device — no internet required, no data leaves your phone. It detects emotional context in real time and responds with empathy, while quietly flagging potential crisis signals to surface helpful resources when needed.

---

##  Features

-  **On-device LLM** — TinyLlama-1.1B fine-tuned for empathetic dialogue, fully offline
-  **Real-time emotion detection** — 7-class emotion classifier (joy, sadness, anger, fear, disgust, surprise, neutral)
-  **Crisis signal detection** — binary risk classifier surfaces support resources when needed
-  **Offline storage** — conversations persist locally via Hive, no cloud sync required
-  **100% private** — no internet connection needed after setup, nothing is ever uploaded

---

##  Architecture

```
User Input
    ↓
DistilBERT Classifier (ONNX)  →  Emotion + Risk Score
    ↓
TinyLlama-1.1B (GGUF, llama.cpp)  →  Empathetic Response
    ↓
Hive (local storage)  →  Persisted Conversation
```

| Component | Model | Format | Size |
|---|---|---|---|
| Conversational LLM | TinyLlama-1.1B-Chat (QLoRA fine-tuned) | GGUF (IQ4_NL) | ~637 MB |
| Emotion/Risk Classifier | DistilBERT (multitask) | ONNX | ~237 MB |

---

##  Tech Stack

- **Frontend:** Flutter
- **LLM Inference:** [llamadart](https://pub.dev/packages/llamadart) (llama.cpp bindings)
- **Classifier Inference:** [onnxruntime](https://pub.dev/packages/onnxruntime)
- **Offline Storage:** [hive](https://pub.dev/packages/hive) + hive_flutter
- **Training:** PyTorch, HuggingFace Transformers, PEFT, TRL, bitsandbytes

---

##  Getting Started

### Prerequisites

- Flutter SDK ≥ 3.0.0
- Android device/emulator (ARM64 recommended)
- ~750 MB free storage for model files

### 1. Clone the repository

```bash
git clone https://github.com/Blackeye6941/emo.git
cd emo/frontend
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Download the model files

Model weights are hosted on Hugging Face Hub). Create the required directories and download the files:

```bash
mkdir -p assets/models
mkdir -p assets/classifier
```

Download the following files and place them in the correct folders:

| File | Destination | Source |
|---|---|---|
| `tinyllama.gguf` | `assets/models/tinyllama.gguf` | [Download from HF →](https://huggingface.co/Blackeye6941/Emotional-assistant_tinyllama-Q4_K_M-GGUF/blob/main/tinyllama.gguf) |
| `classifier.onnx` | `assets/classifier/classifier.onnx` | [Download from HF →](https://huggingface.co/Blackeye6941/Emotion_classifier/blob/main/classifier.onnx) |
| `classifier_config.json` | `assets/classifier/classifier_config.json` | [Download from HF →](http://huggingface.co/Blackeye6941/Emotion_classifier/blob/main/classifier_config.json) |
| `tokenizer_config.json` | `assets/classifier/tokenizer_config.json` | [Download from HF →](https://huggingface.co/Blackeye6941/Emotion_classifier/blob/main/tokenizer_config.json) |
| `vocab.txt` | `assets/classifier/vocab.txt` | [Download from HF →](https://huggingface.co/Blackeye6941/Emotion_classifier/blob/main/vocab.txt) |

**Or download all at once via script:**

```bash
python scripts/download_models.py
```

```python
# scripts/download_models.py
from huggingface_hub import hf_hub_download
import shutil, os
 
LLM_REPO_ID        = "Blackeye6941/Emotional-assistant_tinyllama-Q4_K_M-GGUF"
CLASSIFIER_REPO_ID = "Blackeye6941/Emotion_classifier"
 
os.makedirs("frontend/assets/models", exist_ok=True)
os.makedirs("frontend/assets/classifier", exist_ok=True)
 
# LLM
path = hf_hub_download(repo_id=LLM_REPO_ID, filename="tinyllama.gguf")
shutil.copy(path, "assets/models/tinyllama.gguf")
 
# Classifier files
for f in ["classifier.onnx", "classifier_config.json",
          "tokenizer_config.json", "vocab.txt"]:
    path = hf_hub_download(repo_id=CLASSIFIER_REPO_ID, filename=f)
    shutil.copy(path, f"assets/classifier/{f}")
 
print("All model files downloaded successfully.")
```

### 4. Enable model assets in `pubspec.yaml`

Open `pubspec.yaml` and **uncomment** the model and classifier asset paths:

```yaml
flutter:
  uses-material-design: true
  assets:
    # Uncomment the lines below after downloading model files
    - assets/models/tinyllama.gguf
    - assets/classifier/classifier.onnx
    - assets/classifier/classifier_config.json
    - assets/classifier/tokenizer_config.json
    - assets/classifier/vocab.txt
```

> ⚠️ These are commented out by default since the app won't build without the model files present. Make sure Step 3 is complete before uncommenting.

### 5. Run the app

```bash
flutter run
```

---

##  Project Structure

### Flutter App
```
frontend/
├── lib/
│   ├── main.dart                  # App entry point
│   ├── models/                    # Hive data models
│   ├── screens/                   # UI screens
│   └── services/                  # LLM + classifier inference services
├── assets/
│   ├── models/                    # ⚠️ download required — see Setup
│   │   └── tinyllama.gguf
│   └── classifier/                # ⚠️ download required — see Setup
│       ├── classifier.onnx
│       ├── classifier_config.json
│       ├── tokenizer_config.json
│       └── vocab.txt
├── scripts/
│   └── download_models.py
├── training/                      # Model training scripts (Python)
│   ├── train_tinyllama.py         # Round 1 — EmpatheticDialogues
│   ├── train_round2.py            # Round 2 — MentalChat16K
│   └── train_classifier.py        # DistilBERT emotion + risk classifier
├── pubspec.yaml
└── README.md
```

---

##  Model Training Summary

### TinyLlama Fine-Tuning (QLoRA)

Two sequential fine-tuning rounds were used to build the conversational model:

| Round | Dataset | Purpose | Final Val Loss |
|---|---|---|---|
| Round 1 | [EmpatheticDialogues](https://huggingface.co/datasets/facebook/empathetic_dialogues) | Emotion awareness | 0.958 |
| Round 2 | [MentalChat16K](https://huggingface.co/datasets/ShenLab/MentalChat16K) | Role correction (fix first-person confusion) | 0.820 |

Trained with QLoRA (NF4 4-bit quantization, LoRA rank 16) on a single consumer GPU, then merged and quantized to GGUF (Q4_K_M) for edge deployment.

### Emotion + Risk Classifier

A multitask DistilBERT model with two output heads:
- **Emotion head** — 7-class softmax (joy, sadness, anger, fear, disgust, surprise, neutral)
- **Risk head** — binary sigmoid (0 = safe, 1 = at-risk)

Trained on EmpatheticDialogues, MentalChat16K, and Reddit SuicideWatch, with oversampling and class weighting to address the natural rarity of risk-positive examples.

---

##  Disclaimer

EMO is **not a substitute for professional mental health care**. It is a supportive companion tool. If you or someone you know is in crisis, please reach out to a licensed professional or a crisis hotline:

- **US:** 988 Suicide & Crisis Lifeline — call or text **988**
- **International:** [Find a crisis center near you](https://www.iasp.info/resources/Crisis_Centres/)

---

##  Acknowledgments

- [TinyLlama](https://github.com/jzhang38/TinyLlama) — base conversational model
- [llama.cpp](https://github.com/ggerganov/llama.cpp) — on-device LLM inference engine
- [llamadart](https://pub.dev/packages/llamadart) — Flutter/Dart bindings
- [DistilBERT](https://huggingface.co/distilbert-base-uncased) — base classifier model
- [EmpatheticDialogues](https://huggingface.co/datasets/facebook/empathetic_dialogues), [MentalChat16K](https://huggingface.co/datasets/ShenLab/MentalChat16K) — training datasets
