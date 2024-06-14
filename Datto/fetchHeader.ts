  const fetchFromApi = ({url, fetchHeader}, retry) => {
	const response = fetch(url, fetchHeader)
		.then((res) => res.json())
		.catch((error) => {
			if (!retry) {
				retryUrls.push({url, fetchHeader});
				context.log.warn(error);
			} else {
				context.log.error(error); 
			}
			return;
		});
	return response;
  };