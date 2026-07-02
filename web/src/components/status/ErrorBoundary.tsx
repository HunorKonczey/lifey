"use client";

import { Component, type ReactNode } from "react";
import { ErrorState } from "./ErrorState";

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  /** null falls back to ErrorState's own translated default message. */
  message: string | null;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, message: null };
  }

  static getDerivedStateFromError(error: unknown): State {
    const message = error instanceof Error ? error.message : null;
    return { hasError: true, message };
  }

  reset = () => this.setState({ hasError: false, message: null });

  render() {
    if (this.state.hasError) {
      return (
        this.props.fallback ?? (
          <ErrorState message={this.state.message ?? undefined} onRetry={this.reset} />
        )
      );
    }
    return this.props.children;
  }
}
