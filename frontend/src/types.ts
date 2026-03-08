export interface AuthUser {
  name: string;
  user_id: string;
}

export interface Trip {
  id: string;
  title: string;
  destination?: string;
  start_date?: string;
  end_date?: string;
  notes?: string;
  conversation_id?: string;
  budget?: number | null;
  currency?: string;
}

export interface Conversation {
  id: string;
  title?: string;
}

export interface ConversationMessage {
  role: string;
  parts?: string[];
}

export interface ConversationDetail {
  messages?: ConversationMessage[];
}

export interface SendMessageResponse {
  conversation_id: string;
  assistant_message: string;
}
