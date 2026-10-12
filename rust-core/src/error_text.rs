//! Error text for Swift and the console, with the underlying cause spelled out.
//!
//! rootcause prints each error in a report with its own `Display` only, and
//! reqwest's is just "error sending request for url (…)". Why the request never
//! got out (DNS, a refused or unroutable connection, TLS) is that error's
//! `source()` chain, so it's appended here.

use std::error::Error;

use rootcause::Report;

/// `report` as rootcause prints it, then a `cause:` line for each error in it
/// that has a source chain.
pub(crate) fn report_text(report: &Report) -> String {
    let mut text = format!("{report}").trim_end().to_string();
    for node in report.iter_reports() {
        if let Some(source) = node.current_context_error_source() {
            let shown = node.format_current_context().to_string();
            let causes = chain(source, &shown);
            if !causes.is_empty() {
                text.push_str("\n ↳ cause: ");
                text.push_str(&causes);
            }
        }
    }
    text
}

/// `error` followed by its sources, `: `-separated.
pub(crate) fn error_text(error: &(dyn Error + 'static)) -> String {
    chain(error, "")
}

/// The messages from `first` down its source chain, leaving out any already in
/// `shown` or an earlier message: some errors repeat their source's message in
/// their own, which would otherwise print twice.
fn chain(first: &(dyn Error + 'static), shown: &str) -> String {
    let mut parts: Vec<String> = Vec::new();
    let mut next = Some(first);
    while let Some(error) = next {
        let message = error.to_string();
        if !message.is_empty()
            && !shown.contains(&message)
            && !parts.iter().any(|part| part.contains(&message))
        {
            parts.push(message);
        }
        next = error.source();
    }
    parts.join(": ")
}

#[cfg(test)]
mod tests {
    use super::*;
    use rootcause::prelude::*;
    use std::fmt;

    /// An error wrapping another, as reqwest wraps hyper's and hyper the OS's.
    #[derive(Debug)]
    struct Wrapper(&'static str, Option<Box<dyn Error + Send + Sync>>);

    impl fmt::Display for Wrapper {
        fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
            f.write_str(self.0)
        }
    }

    impl Error for Wrapper {
        fn source(&self) -> Option<&(dyn Error + 'static)> {
            self.1.as_deref().map(|e| e as &(dyn Error + 'static))
        }
    }

    /// Shaped like the reqwest error behind a failed URL-bag fetch.
    fn send_error() -> Wrapper {
        let os = std::io::Error::other(
            "failed to lookup address information: nodename nor servname provided, or not known",
        );
        let dns = Wrapper("dns error", Some(Box::new(os)));
        let hyper = Wrapper("client error (Connect)", Some(Box::new(dns)));
        Wrapper(
            "error sending request for url (https://gsa.apple.com/grandslam/GsService2/lookup)",
            Some(Box::new(hyper)),
        )
    }

    /// As isideload builds it: the reqwest error under a context.
    fn fetch_url_bag() -> Result<(), Report> {
        let sent: Result<(), Wrapper> = Err(send_error());
        sent.context("Failed to fetch URL Bag")?;
        Ok(())
    }

    #[test]
    fn a_report_names_why_the_request_failed() {
        let text = report_text(&fetch_url_bag().unwrap_err());
        assert!(text.contains("Failed to fetch URL Bag"), "{text}");
        assert!(text.contains("error sending request for url"), "{text}");
        assert!(
            text.ends_with(
                "\n ↳ cause: client error (Connect): dns error: failed to lookup address \
                 information: nodename nor servname provided, or not known"
            ),
            "{text}"
        );
    }

    #[test]
    fn a_report_without_sources_is_unchanged() {
        let expired = || -> Result<(), Report> {
            Err(report!("Developer error 1100: expired"))?;
            Ok(())
        };
        let report = expired().unwrap_err();
        assert_eq!(report_text(&report), format!("{report}").trim_end());
    }

    #[test]
    fn an_error_lists_its_chain_once() {
        let inner = Wrapper("connection refused", None);
        let outer = Wrapper("tcp connect error: connection refused", Some(Box::new(inner)));
        assert_eq!(error_text(&outer), "tcp connect error: connection refused");
        assert_eq!(
            error_text(&send_error()),
            "error sending request for url (https://gsa.apple.com/grandslam/GsService2/lookup): \
             client error (Connect): dns error: failed to lookup address information: \
             nodename nor servname provided, or not known"
        );
    }
}
