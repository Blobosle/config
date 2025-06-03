return require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'

    use 'morhetz/gruvbox'

    use 'ribru17/bamboo.nvim'

    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.6',
        requires = { {'nvim-lua/plenary.nvim'} }
    }

    use 'nvim-telescope/telescope-fzy-native.nvim'

    use "nvim-lua/plenary.nvim"

    use {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        requires = { {"nvim-lua/plenary.nvim"} }
    }

    use {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "neovim/nvim-lspconfig",
    }

    use 'karb94/neoscroll.nvim'

    use {
        'numToStr/Comment.nvim',
        config = function()
            require('Comment').setup()
        end
    }

    use 'sainnhe/everforest'

    use 'gaborvecsei/memento.nvim'

    use 'xiyaowong/transparent.nvim'

    use {
        'sts10/vim-pink-moon',
        lock = true,
    }

    use 'p00f/godbolt.nvim'

    use 'navarasu/onedark.nvim'


    use {
        'MeanderingProgrammer/render-markdown.nvim',
        config = function()
            require('render-markdown').setup()
        end
    }

    use 'subnut/nvim-ghost.nvim'

    use {
        'nvim-treesitter/nvim-treesitter',
        run = function()
            local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
            ts_update()
        end,
    }

    use 'saghen/blink.cmp'
end)
