const API = "/api/items";

document.addEventListener("DOMContentLoaded", () => {
  loadItems();

  document.getElementById("itemForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const name = document.getElementById("name").value.trim();
    const description = document.getElementById("description").value.trim();
    if (!name) return;

    try {
      const res = await fetch(API, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, description }),
      });
      if (res.ok) {
        document.getElementById("itemForm").reset();
        loadItems();
      } else {
        const err = await res.json();
        alert(err.error || "Failed to add item");
      }
    } catch (err) {
      alert("Network error");
    }
  });
});

async function loadItems() {
  const container = document.getElementById("itemsList");
  try {
    const res = await fetch(API);
    const items = await res.json();
    if (!items.length) {
      container.innerHTML = '<p class="muted">No items yet. Add one above!</p>';
      return;
    }
    container.innerHTML = items
      .map(
        (item) => `
      <div class="item">
        <div class="item-info">
          <h3>${escapeHtml(item.name)}</h3>
          <p>${escapeHtml(item.description || "")}</p>
          <small class="muted">${new Date(item.created_at).toLocaleString()}</small>
        </div>
        <div class="item-actions">
          <button class="btn btn-danger" onclick="deleteItem(${item.id})">Delete</button>
        </div>
      </div>`
      )
      .join("");
  } catch {
    container.innerHTML = '<p class="muted">Could not load items. Is the database connected?</p>';
  }
}

async function deleteItem(id) {
  if (!confirm("Delete this item?")) return;
  try {
    const res = await fetch(`${API}/${id}`, { method: "DELETE" });
    if (res.ok) loadItems();
  } catch {
    alert("Failed to delete");
  }
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}
