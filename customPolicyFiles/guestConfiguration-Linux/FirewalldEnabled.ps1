Configuration FirewalldEnabled {
    
    Import-DscResource -ModuleName 'GuestConfiguration'

    Node FirewalldEnabled {
        
        ChefInSpecResource FirewalldEnabled {
            Name = 'FirewalldEnabled'
            GithubPath = "FirewalldEnabled/Modules/FirewalldEnabled/";
        }
    }
}