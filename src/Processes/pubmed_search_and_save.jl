using BioMedQuery.PubMed
using BioServices.EUtils
using SQLite
using MySQL
using XMLDict
using LightXML



"""
    pubmed_search_and_save!(email, search_term::String, article_max,
    conn, verbose=false)

Search pubmed and save the results into a database connection. The database is expected to exist and 
have the appriate pubmed related tables. You can create such tables using 
`PubMed.create_tables(conn)`    

###Arguments

* email: valid email address (otherwise pubmed may block you)
* search_term : search string to submit to PubMed
e.g (asthma[MeSH Terms]) AND ("2001/01/29"[Date - Publication] : "2010"[Date - Publication])
see http://www.ncbi.nlm.nih.gov/pubmed/advanced for help constructing the string
* article_max : maximum number of articles to return
* conn: database connection
* verbose: if true, the NCBI xml response files are saved to current directory
"""
function pubmed_search_and_save!(email, search_term::String, article_max,
    conn, verbose=false)

    retstart = 0
    retmax = 10000  #e-utils only allows 10,000 at a time
    article_max = article_max

    if article_max < retmax
        retmax = article_max
    end

    db = nothing
    article_total = 0

    for rs=retstart:retmax:(article_max- 1)

        rm = rs + retmax
        if rm > article_max
            retmax = article_max - rs
        end

        println("Getting ", retmax, " articles, starting at index ", rs)

        println("------ESearch--------")

        esearch_response = esearch(db = "pubmed", term = search_term,
        retstart = rs, retmax = retmax, tool = "BioJulia",
        email = email)

        # if verbose
        #     xdoc = parse_string(esearch_response)
        #     save_file(xdoc, "./esearch.xml")
        # end

        #convert xml to dictionary
        esearch_dict = parse_xml(String(esearch_response.data))
        
        if !haskey(esearch_dict, "IdList")
            println("Error with esearch_dict:")
            println(esearch_dict)
            error("Response esearch_dict does not contain IdList")
        end

        println("------EFetch--------")
        
        #get the list of ids and perfom a fetch
        ids = [parse(Int64, id_node) for id_node in esearch_dict["IdList"]["Id"]]

        efetch_response = efetch(db = "pubmed", tool = "BioJulia", retmode = "xml", rettype = "null", id = ids)

        # if verbose
        #     xdoc = parse_string(efetch_response)
        #     save_file(xdoc, "./efetch.xml")
        # end

        #convert xml to dictionary
        efetch_dict = parse_xml(String(efetch_response.data))

        #save the results of an entrez fetch
        println("------Save to database--------")
        
        save_efetch!(conn, efetch_dict, verbose)

        article_total+=length(ids)

        if (length(ids) < retmax)
            break
        end

    end

    println("Finished searching, total number of articles: ", article_total)
    return db
end


function pubmed_pmid_search(email, search_term::String, article_max, verbose=false)

     retstart = 0
     retmax = 10000  #e-utils only allows 10,000 at a time
     article_max = article_max

     if article_max < retmax
         retmax = article_max
     end

     all_pmids = Array{Int64,1}()
     article_total = 0

     for rs=retstart:retmax:(article_max- 1)

        rm = rs + retmax
        if rm > article_max
            retmax = article_max - rs
        end

        println("Getting ", retmax, " articles, starting at index ", rs)
        
        println("------ESearch--------")

        esearch_response = esearch(db = "pubmed", term = search_term,
        retstart = rs, retmax = retmax, tool = "BioJulia",
        email = email)

        if verbose
            xdoc = parse_string(esearch_response)
            save_file(xdoc, "./esearch.xml")
        end

        #convert xml to dictionary
        esearch_dict = parse_xml(String(esearch_response.data))

        if !haskey(esearch_dict, "IdList")
            println("Error with esearch_dict:")
            println(esearch_dict)
            error("Response esearch_dict does not contain IdList")
        end

        #get the list of ids and perfom a fetch
        ids = [parse(Int64, id_node) for id_node in esearch_dict["IdList"]["Id"]]
         
        append!(all_pmids, ids)

        article_total+=length(ids)

        if (length(ids) < retmax)
            break
        end

     end

     println("Finished searching, total number of articles: ", article_total)

     return all_pmids
 end

function pubmed_pmid_search_and_save!(email, search_term::String, article_max,
    conn, verbose=false)

    pmids = pubmed_pmid_search(email, search_term, article_max, verbose)
    db = save_pmids!(conn, pmids, verbose)

    narticles = length(pmids)
    info("Finished saving $narticles articles")

    return nothing
end
