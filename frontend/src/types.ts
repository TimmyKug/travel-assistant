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
  itinerary?: Array<Record<string, unknown>>;
  conversation_id?: string;
  budget?: number | null;
  currency?: string;
}

export interface Conversation {
  id: string;
  title?: string;
  updated_at?: string;
  recommendations?: string[];
}

export interface ConversationMessage {
  role: string;
  parts?: string[];
}

export interface ConversationDetail {
  id?: string;
  title?: string;
  messages?: ConversationMessage[];
  updated_at?: string;
  recommendations?: string[];
}

export interface SendMessageResponse {
  conversation_id: string;
  assistant_message: string;
  recommendations: string[];
  trip_plan?: TripPlan | null;
}

export interface TripTimelineItem {
  time: string;
  title: string;
  description: string;
  category: "transport" | "activity" | "food" | "hotel" | "note" | string;
  estimated_cost?: string;
}

export interface TripTimelineDay {
  day: number;
  date?: string;
  items: TripTimelineItem[];
}

export interface TripPlan {
  trip_title: string;
  destination: string;
  summary?: string;
  hotels?: Array<
    | {
        night: number;
        date?: string;
        options: Array<{
          name: string;
          area?: string;
          nightly_estimate?: string;
          reason?: string;
        }>;
      }
    | {
    name: string;
    area?: string;
    nightly_estimate?: string;
    reason?: string;
      }
  >;
  days: TripTimelineDay[];
  budget?: {
    currency?: string;
    estimated_total?: string;
    notes?: string;
  };
}
