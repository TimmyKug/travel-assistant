import axios from "axios";

const api = axios.create({ baseURL: "/api" });

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem("token");
      localStorage.removeItem("user");
      window.location.href = "/login";
    }
    return Promise.reject(err);
  }
);

export const sendMessage       = (content, conversation_id = null) =>
  api.post("/ai/chat", { content, conversation_id }).then(r => r.data);
export const listConversations = ()         => api.get("/ai/conversations").then(r => r.data);
export const getConversation   = (id)       => api.get(`/ai/conversations/${id}`).then(r => r.data);
export const listTrips         = ()         => api.get("/trips/").then(r => r.data);
export const createTrip        = (data)     => api.post("/trips/", data).then(r => r.data);
export const updateTrip        = (id, data) => api.put(`/trips/${id}`, data).then(r => r.data);
export const deleteTrip        = (id)       => api.delete(`/trips/${id}`);
