import json
import os
from pathlib import Path

from google.cloud import firestore


STATE_FILE = Path(os.environ.get("INTEGRATION_STATE_FILE", ".integration-test-state.json"))


def delete_document_tree(doc_ref):
    for collection in doc_ref.collections():
        delete_collection(collection)
    doc_ref.delete()


def delete_collection(collection_ref, batch_size=50):
    while True:
        docs = list(collection_ref.limit(batch_size).stream())
        if not docs:
            break
        for doc in docs:
            delete_document_tree(doc.reference)


def main():
    project_id = os.environ["GCP_PROJECT_ID"]
    email = os.environ.get("TEST_EMAIL")
    user_id = None

    if STATE_FILE.exists():
        state = json.loads(STATE_FILE.read_text())
        email = state.get("email") or email
        user_id = state.get("user_id")

    if not email and not user_id:
        print("No integration-test user id or email found; nothing to clean.")
        return

    db = firestore.Client(project=project_id)
    refs = []

    if user_id:
        refs.append(db.collection("users").document(user_id))

    if email:
        for doc in db.collection("users").where("email", "==", email).stream():
            if all(doc.reference.path != ref.path for ref in refs):
                refs.append(doc.reference)

    if not refs:
        print("No integration-test Firestore documents found.")
        return

    for ref in refs:
        print(f"Deleting Firestore test document tree: {ref.path}")
        delete_document_tree(ref)


if __name__ == "__main__":
    main()
